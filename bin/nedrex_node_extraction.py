#!/usr/bin/env python
import argparse
import logging
import os
from urllib.parse import urljoin

import pandas as pd
import requests

from generate_NEDREX_API_key import get_pagination_max

# Configure logger
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
_handler = logging.StreamHandler()
_handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s [%(name)s] %(message)s"))
logger.addHandler(_handler)


def list_node_collections(endpoint_url: str, api_key: str = None) -> list:
    """
    Fetch list of node collections from the NeDRex API.
    Parameters:
        endpoint_url (str): Base URL of the API (e.g., 'https://api.nedrex.net/').
        api_key (str): Optional API key for authentication.
    Returns:
        list: A list of collection names.
    """
    headers = {}
    if api_key:
        headers["x-api-key"] = api_key
    # Ensure proper URL joining
    url = urljoin(endpoint_url if endpoint_url.endswith('/') else endpoint_url + '/', "list_node_collections")
    response = requests.get(url, headers=headers)
    response.raise_for_status()
    return response.json()


def list_edge_collections(endpoint_url: str, api_key: str = None) -> list:
    """
    Fetch list of edge collections from the NeDRex API.
    Parameters:
        endpoint_url (str): Base URL of the API (e.g., 'https://api.nedrex.net/').
        api_key (str): Optional API key for authentication.
    Returns:
        list: A list of collection names.
    """
    headers = {}
    if api_key:
        headers["x-api-key"] = api_key
    # Ensure proper URL joining
    url = urljoin(endpoint_url if endpoint_url.endswith('/') else endpoint_url + '/', "list_edge_collections")
    response = requests.get(url, headers=headers)
    response.raise_for_status()
    return response.json()


# api key can be null, return is pandas dataframe
def fetch_nodes(endpoint_url: str, collection: str, api_key: str = None) -> pd.DataFrame:
    """
    Fetch nodes from the NeDRex API.
    Parameters:
        endpoint_url (str): The URL of the endpoint to fetch nodes from.
        api_key (str): The API key for authentication.

    Returns:
        dict: The response data from the API.
    """

    # Check if the collection is valid
    node_collections = list_node_collections(endpoint_url, api_key)
    edge_collections = list_edge_collections(endpoint_url, api_key)
    if collection not in node_collections and collection not in edge_collections:
        raise ValueError(
            f"Collection '{collection}' is not valid. Valid collections are: {node_collections + edge_collections}")

    headers = {}
    if api_key:
        headers["x-api-key"] = api_key
    offset = 0
    all_records = []
    pagination_max = get_pagination_max(api_key, endpoint_url)
    # endpoint/collection/all is the url, make sure to deal witrh the fact that the base url might have a / or might not
    url = urljoin(endpoint_url, f"{collection}/all")
    while True:
        params = {"offset": offset, "limit": pagination_max}
        resp = requests.get(url, headers=headers, params=params)
        resp.raise_for_status()
        if resp.status_code == 404:
            raise RuntimeError(f"Failed to fetch nodes: {resp.status_code} {resp.text}")
        elif resp.status_code == 422:
            raise RuntimeError(f"Failed to fetch nodes: {resp.status_code} {resp.text}")
        elif resp.status_code == 200:
            logging.info(f"Nodes fetched successfully: {resp.status_code}")
            batch = resp.json()
            all_records.extend(batch)
            # stop when we get fewer than limit
            if len(batch) < pagination_max:
                break
            offset += pagination_max
    return pd.DataFrame(all_records)


def main():

    parser = argparse.ArgumentParser(
        description="Fetch specified node collections from the NeDRex API and save to CSV files")
    parser.add_argument('--base-url', '-u', default='https://api.nedrex.net/licensed',
        help='Base URL of the NeDRex API')
    parser.add_argument('-c', '--collections', nargs='+', required=True,
        help='One or more collection names to download')
    parser.add_argument('--output', '-o', required=True, help='Output directory to save CSV files')
    parser.add_argument('--api-key', '-k', dest='api_key', help='API key for authentication')
    args = parser.parse_args()
    if args.api_key:
        api_key = args.api_key
        logger.info("Using API key from command line argument")
    else:
        api_key = os.getenv("NEDREX_LICENSED_KEY")
        if api_key:
            logger.info("Loaded API key from environment variable NEDREX_LICENSED_KEY")
        else:
            logger.warning("No API key provided (via --api-key or environment); requests may fail if authentication is required")
    os.makedirs(args.output, exist_ok=True)
    for collection in args.collections:
        try:
            df = fetch_nodes(args.base_url, collection, api_key)
            output_path = os.path.join(args.output, f"{collection}.csv")
            df.to_csv(output_path, index=False)
            logger.info(f"Saved collection '{collection}' to {output_path}")
        except Exception as e:
            logger.error(f"Failed to fetch or save collection '{collection}': {e}")


if __name__ == '__main__':
    #sys.argv = ['nedrex_node_extraction.py','--base-url', 'https://api.nedrex.net/licensed', '--collections', 'disorder', 'drug', '--output', './data']
    main()
