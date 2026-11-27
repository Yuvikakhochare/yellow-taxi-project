import hashlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import duckdb

from src import ingest


class TestIngestionValidation(unittest.TestCase):

    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.project_dir = Path(self.temp_dir.name)

        self.raw_dir = self.project_dir / "raw"
        self.raw_dir.mkdir()

        self.zone_file = self.raw_dir / "taxi_zone_lookup.csv"
        self.zone_file.write_text(
            "LocationID,Borough,Zone,service_zone\n",
            encoding="utf-8"
        )

        self.months = list(ingest.MONTHS)

        self.raw_patch = patch.object(
            ingest, "RAW_DATA_DIR", self.raw_dir
        )
        self.zone_patch = patch.object(
            ingest, "ZONE_LOOKUP_FILE", self.zone_file
        )

        self.raw_patch.start()
        self.zone_patch.start()

    def tearDown(self):
        self.raw_patch.stop()
        self.zone_patch.stop()
        self.temp_dir.cleanup()

    def create_monthly_files(self):
        for month in self.months:
            file_path = self.raw_dir / f"yellow_tripdata_{month}.parquet"
            file_path.write_bytes(b"sample data")

    def create_parquet_file(self, file_path, value):
        escaped_path = str(file_path).replace("'", "''")

        connection = duckdb.connect()
        try:
            connection.execute(
                f"COPY (SELECT {value} AS trip_id) "
                f"TO '{escaped_path}' (FORMAT PARQUET)"
            )
        finally:
            connection.close()

    def test_all_monthly_files_are_found(self):
        self.create_monthly_files()

        result = ingest.get_source_files()

        self.assertEqual(len(result), 12)
        self.assertIn("2025-01", result)
        self.assertIn("2025-12", result)

    def test_missing_month_raises_error(self):
        self.create_monthly_files()

        missing_file = (
            self.raw_dir / f"yellow_tripdata_{self.months[0]}.parquet"
        )
        missing_file.unlink()

        with self.assertRaises(FileNotFoundError):
            ingest.get_source_files()

    def test_empty_monthly_file_raises_error(self):
        self.create_monthly_files()

        empty_file = (
            self.raw_dir / f"yellow_tripdata_{self.months[0]}.parquet"
        )
        empty_file.write_bytes(b"")

        with self.assertRaises(ValueError):
            ingest.get_source_files()

    def test_file_hash_is_consistent(self):
        sample_file = self.project_dir / "sample.txt"
        sample_file.write_bytes(b"yellow taxi data")

        expected_hash = hashlib.sha256(
            b"yellow taxi data"
        ).hexdigest()

        actual_hash = ingest.calculate_file_hash(sample_file)

        self.assertEqual(actual_hash, expected_hash)

    def test_month_is_ingested_only_once(self):
        connection = duckdb.connect(":memory:")

        try:
            ingest.create_control_tables(connection)

            connection.execute("""
                CREATE TABLE raw_trips (
                    trip_id INTEGER,
                    source_month VARCHAR,
                    source_file VARCHAR
                )
            """)

            parquet_file = self.raw_dir / "sample.parquet"
            self.create_parquet_file(parquet_file, 1)

            first_result = ingest.ingest_month(
                connection, "2025-01", parquet_file
            )

            second_result = ingest.ingest_month(
                connection, "2025-01", parquet_file
            )

            row_count = connection.execute(
                "SELECT COUNT(*) FROM raw_trips"
            ).fetchone()[0]

            self.assertEqual(first_result, 1)
            self.assertEqual(second_result, 0)
            self.assertEqual(row_count, 1)

        finally:
            connection.close()

    def test_changed_source_file_is_rejected(self):
        connection = duckdb.connect(":memory:")

        try:
            ingest.create_control_tables(connection)

            connection.execute("""
                CREATE TABLE raw_trips (
                    trip_id INTEGER,
                    source_month VARCHAR,
                    source_file VARCHAR
                )
            """)

            parquet_file = self.raw_dir / "sample.parquet"
            self.create_parquet_file(parquet_file, 1)

            ingest.ingest_month(
                connection, "2025-01", parquet_file
            )

            parquet_file.unlink()
            self.create_parquet_file(parquet_file, 2)

            with self.assertRaises(ValueError):
                ingest.ingest_month(
                    connection, "2025-01", parquet_file
                )

        finally:
            connection.close()


if __name__ == "__main__":
    unittest.main()