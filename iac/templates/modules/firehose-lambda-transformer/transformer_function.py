# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import json
import base64
import logging
import traceback
from typing import Dict, List, Any, Optional

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)


class FirehoseTransformer:
    """Handles transformation of DMS records for Kinesis Data Firehose"""

    @staticmethod
    def decode_record_payload(record: Dict[str, Any]) -> Optional[str]:
        """
        Decode payload from MSK or Kinesis record

        Args:
            record: The input record from Firehose

        Returns:
            Decoded payload string or None if unable to decode
        """
        try:
            if "kafkaRecordValue" in record:
                return base64.b64decode(record["kafkaRecordValue"]).decode("utf-8")
            elif "data" in record:
                return base64.b64decode(record["data"]).decode("utf-8")

            return None

        except (base64.binascii.Error, UnicodeDecodeError) as e:
            logger.error(f"Failed to decode record payload: {e}")
            return None

    @staticmethod
    def extract_transaction_data(record: Dict[str, Any]) -> Optional[tuple]:
        """
        Extract transaction data from DMS envelope

        Args:
            dms_record: Parsed DMS JSON record

        Returns:
            Tuple of (transaction_data, operation) or None if not found
        """
        if "data" in record:
            transaction_data = record["data"]
            transformed_data = {
                key.lower(): value for key, value in transaction_data.items()
            }
            dms_op = record.get("metadata", {}).get("operation")
            operation = dms_op if dms_op in ("update", "delete") else "insert"
            return transformed_data, operation
        elif "after" in record or "key" in record:
            operation_mapping = {"u": "update", "d": "delete"}
            op_code = record.get("op")
            operation = operation_mapping.get(op_code, "insert") if op_code else "insert"

            if operation == "delete":
                transaction_data = record.get("key")
            else:
                transaction_data = record.get("after")

            return transaction_data, operation

        return None

    @staticmethod
    def create_output_record(
        record_id: str,
        transformed_data: Dict[str, Any],
        is_msk_record: bool,
        operation: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Create output record for Firehose

        Args:
            record_id: Original record ID
            transformed_data: Transformed transaction data
            is_msk_record: Whether this is an MSK record
            operation: Operation type (insert, update, delete) if available

        Returns:
            Formatted output record for Firehose
        """
        output_data = json.dumps(transformed_data) + "\n"
        encoded_data = base64.b64encode(output_data.encode("utf-8")).decode("utf-8")
        data_field = "kafkaRecordValue" if is_msk_record else "data"
        return_value = {"recordId": record_id, "result": "Ok", data_field: encoded_data}
        if operation:
            return_value["metadata"] = {"otfMetadata": {"operation": operation}}

        return return_value

    @staticmethod
    def create_dropped_record(record_id: str) -> Dict[str, Any]:
        """Create a dropped processing record"""
        return {"recordId": record_id, "result": "Dropped"}

    @staticmethod
    def create_failed_record(record_id: str) -> Dict[str, Any]:
        """Create a failed processing record"""
        return {"recordId": record_id, "result": "ProcessingFailed"}


def handler(event: Dict[str, Any], context: Any) -> Dict[str, List[Dict[str, Any]]]:
    """
    Lambda handler for Amazon Data Firehose transformation.
    Processes DMS envelope records and CockroachDB changefeeds from MSK sources,
    flattening them into individual transaction records for Iceberg ingestion.

    Args:
        event: Firehose transformation event containing records to process
        context: Lambda context object

    Returns:
        Firehose transformation response with processed records
    """
    transformer = FirehoseTransformer()
    output_records = []

    try:
        records = event.get("records", [])
        logger.info(f"Processing {len(records)} records")

        for record in records:
            record_id = record.get("recordId", "unknown")

            try:
                payload = transformer.decode_record_payload(record)
                if payload is None:
                    logger.warning(
                        f"Unknown record format for {record_id}: {list(record.keys())}"
                    )
                    output_records.append(transformer.create_failed_record(record_id))
                    continue
                try:
                    stream_record = json.loads(payload)
                    logger.debug(f"Parsed payload: {stream_record}")
                except json.JSONDecodeError as e:
                    logger.error(f"Invalid JSON in record {record_id}: {e}")
                    output_records.append(transformer.create_failed_record(record_id))
                    continue
                # Drop CockroachDB resolved timestamp messages
                if "resolved" in stream_record and not any(
                    k in stream_record for k in ("data", "after", "metadata")
                ):
                    logger.debug(
                        f"Dropping CockroachDB resolved timestamp for record {record_id}: "
                        f"{stream_record['resolved']}"
                    )
                    output_records.append(transformer.create_dropped_record(record_id))
                    continue
                if "metadata" in stream_record:
                    metadata = stream_record["metadata"]
                    logger.debug(
                        f"DMS operation: {metadata.get('operation')}, "
                        f"table: {metadata.get('table-name')}"
                    )
                extraction_result = transformer.extract_transaction_data(stream_record)
                if extraction_result is None:
                    logger.warning(f"No transaction data found in record {record_id}")
                    output_records.append(transformer.create_failed_record(record_id))
                    continue
                transaction_data, operation = extraction_result
                is_msk_record = "kafkaRecordValue" in record
                output_record = transformer.create_output_record(
                    record_id, transaction_data, is_msk_record, operation
                )
                output_records.append(output_record)

                logger.debug(f"Successfully processed record {record_id}")

            except Exception as e:
                logger.error(f"Error processing record {record_id}: {e}")
                logger.debug(f"Traceback: {traceback.format_exc()}")
                output_records.append(transformer.create_failed_record(record_id))
        ok_count = sum(1 for r in output_records if r["result"] == "Ok")
        dropped_count = sum(1 for r in output_records if r["result"] == "Dropped")
        failed_count = len(output_records) - ok_count - dropped_count
        logger.info(
            f"Processing complete - Success: {ok_count}, Dropped: {dropped_count}, Failed: {failed_count}"
        )

        return {"records": output_records}

    except Exception as e:
        logger.error(f"Fatal handler error: {e}")
        logger.error(f"Traceback: {traceback.format_exc()}")
        failed_records = []
        for record in event.get("records", []):
            failed_records.append(
                transformer.create_failed_record(record.get("recordId", "unknown"))
            )

        return {"records": failed_records}
