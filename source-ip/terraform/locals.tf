locals {
  release_data = jsondecode(data.http.github_latest_release.response_body)

  # Find the zipball_url from the release data
  download_url = local.release_data.zipball_url

  # Extract tag name for versioning
  tag_name = local.release_data.tag_name

  # Create a unique filename based on repo and tag
  zip_filename = "${replace(var.github_repo, "/", "-")}-${local.tag_name}.zip"
}
