import openmeteo_requests
import requests_cache
from retry_requests import retry
import logging

# Common Constants
FORECAST_API_URL = "https://api.open-meteo.com/v1/forecast"
ARCHIVE_API_URL = "https://archive-api.open-meteo.com/v1/archive"
HISTORICAL_FORECAST_API_URL = "https://historical-forecast-api.open-meteo.com/v1/forecast"

# Logging Setup
logger = logging.getLogger(__name__)

def setup_client(cache_name='.cache', expire_after=3600, retries=5, backoff_factor=0.2):
    """
    Sets up the Open-Meteo client with caching and retry logic.
    """
    cache_session = requests_cache.CachedSession(cache_name, expire_after=expire_after)
    retry_session = retry(cache_session, retries=retries, backoff_factor=backoff_factor)
    return openmeteo_requests.Client(session=retry_session)
