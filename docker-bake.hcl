
target "docker-metadata-action" {}
target "docker-platforms" {}

group "default" {
  targets = [
    "cli",
    "hardhat",
  ]
}

target "hardhat" {
  inherits = ["docker-metadata-action", "docker-platforms"]
  context  = "./onchain"
  target   = "hardhat"
}

target "cli" {
  inherits = ["docker-metadata-action", "docker-platforms"]
  context  = "./onchain"
  target   = "cli"
}

target "deployments" {
  inherits   = ["docker-metadata-action"]
  dockerfile = "onchain/Dockerfile"
  target     = "deployments"
  context    = "."
  platforms = [
    "linux/amd64",
    "linux/arm64",
    "linux/riscv64"
  ]
}
