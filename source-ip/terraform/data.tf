data "aws_route53_zone" "main" {
  name         = var.route53_zone_name
  private_zone = false
}

data "http" "github_latest_release" {
  url = "https://api.github.com/repos/${var.github_repo}/releases/latest"

  request_headers = {
    Accept = "application/vnd.github.v3+json"
  }
}

data "external" "download_github_release" {
  program = ["bash", "-c", <<-EOT
    set -e
    
    mkdir -p ./downloads
    curl -L -o "./downloads/${local.zip_filename}" "${local.download_url}"
    
    # Get file size and calculate hash for verification
    if [ -f "./downloads/${local.zip_filename}" ]; then
      SIZE=$(stat -f%z "./downloads/${local.zip_filename}" 2>/dev/null || stat -c%s "./downloads/${local.zip_filename}" 2>/dev/null || echo "0")
      HASH=$(sha256sum "./downloads/${local.zip_filename}" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "./downloads/${local.zip_filename}" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
      echo "{\"filename\":\"./downloads/${local.zip_filename}\",\"size\":\"$SIZE\",\"hash\":\"$HASH\",\"tag\":\"${local.tag_name}\"}"
    else
      echo "{\"error\":\"Failed to download file\"}"
      exit 1
    fi
EOT
  ]

  # Trigger re-download when the tag changes
  query = {
    download_url = local.download_url
    tag_name     = local.tag_name
    filename     = local.zip_filename
  }
}
