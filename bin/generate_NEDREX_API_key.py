#!/usr/bin/env python
from urllib.parse import urljoin

import requests
import argparse


class NeDRexService:
    API_LINK = "https://exbio.wzw.tum.de/repo4eu_nedrex_licensed/"
  #  API_LINK = "https://api.nedrex.net/licensed/"
    CREDENTIALS_ROUTE = "admin/api_key/generate"
    PAGINATION_MAX_ROUTE = "pagination_max"


def get_api_key(base_url: str = None) -> dict | None:
    """
    Generate an API key.

    If base_url is provided, use it; otherwise use NeDRexService.API_LINK.
    Ensures the base_url ends with a slash before appending the credentials route.
    """
    # Determine the base URL and ensure it ends with '/'
    base = base_url or NeDRexService.API_LINK
    if not base.endswith('/'):
        base += '/'

    # Ensure the route does not start with a slash to avoid '//' in the URL
    route = NeDRexService.CREDENTIALS_ROUTE.lstrip('/')
    url = base + route

    headers = {'Content-Type': 'application/json'}
    payload = {"accept_eula": True}

    try:
        response = requests.post(url, json=payload, headers=headers)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as error:
        raise RuntimeError(f"Failed to generate API key: {error}")


def get_pagination_max(api_key, url) -> int:
    url = urljoin(url, f"{NeDRexService.PAGINATION_MAX_ROUTE}")
    headers = {'Content-Type': 'application/json', 'x-api-key': api_key}
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        # return pagination max
        if response.status_code == 200:
            return int(response.text)
        else:
            raise RuntimeError(f"Failed to get pagination max: {response.status_code} {response.text}")
    except requests.exceptions.RequestException as e:
        raise RuntimeError(f"Failed to get pagination max: {e}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate NeDRex API key (optionally using a custom base URL) and fetch pagination max."
    )
    parser.add_argument(
        "-b", "--base-url",
        help="Custom base URL for the NeDRexService API (default uses the built-in URL).",
        default=None
    )
    # add argument to only print the API key
    parser.add_argument(
        "--print-key",
        action="store_true",
        help="If set, only prints the generated API key without fetching pagination max."
    )
    args = parser.parse_args()

    api_key = get_api_key(args.base_url)
    if not api_key:
        raise RuntimeError("Failed to generate API key.")
    if args.print_key:
        print(f"{api_key}")
        exit(0)
    print(f"Generated API key: {api_key}")

    pagination_max = get_pagination_max(str(api_key),args.base_url)
    if not pagination_max:
        raise RuntimeError("Failed to retrieve pagination max.")

    print("Upper limit for pagination:", pagination_max)