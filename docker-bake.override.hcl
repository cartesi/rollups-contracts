
variable "TAG" {
  default = "devel"
}

variable "DOCKER_ORGANIZATION" {
  default = "cartesi"
}

target "hardhat" {
  tags = ["${DOCKER_ORGANIZATION}/rollups-hardhat:${TAG}"]
}

target "cli" {
  tags = ["${DOCKER_ORGANIZATION}/rollups-cli:${TAG}"]
}

target "deployments" {
  tags = ["${DOCKER_ORGANIZATION}/rollups-deployments:${TAG}"]
}
