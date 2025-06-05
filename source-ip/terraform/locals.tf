locals {
  release_data = jsondecode(data.http.github_latest_release.response_body)

  # Find the zipball_url from the release data
  download_url = local.target_asset.browser_download_url

  # Extract tag name for versioning
  tag_name = local.release_data.tag_name

  # Create a unique filename based on repo and tag
  zip_filename = local.target_asset.name

  asset_pattern = "source-ip-${local.tag_name}-linux-arm64.zip"
  target_asset = [
    for asset in local.release_data.assets :
    asset if asset.name == local.asset_pattern
  ][0]
}
