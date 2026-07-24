import time
import logging
import os
import random

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
logger = logging.getLogger(__name__)

ENVIRONMENT = os.environ.get("ENVIRONMENT", "dev")
PROCESS_INTERVAL = int(os.environ.get("PROCESS_INTERVAL", "10"))

def process_batch():
    batch_size = random.randint(5, 50)
    logger.info(f"[{ENVIRONMENT}] Processing batch of {batch_size} events...")
    time.sleep(1)
    logger.info(f"[{ENVIRONMENT}] Batch complete. Processed {batch_size} events.")
    return batch_size

def run():
    logger.info(f"Data processor starting in environment: {ENVIRONMENT}")
    total = 0
    while True:
        try:
            count = process_batch()
            total += count
            logger.info(f"[{ENVIRONMENT}] Cumulative total processed: {total}")
        except Exception as e:
            logger.error(f"Processor error: {e}")
        time.sleep(PROCESS_INTERVAL)

if __name__ == "__main__":
    run()
