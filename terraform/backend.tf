terraform {
  cloud {
    organization = "omer-levi"

    workspaces {
      name = "fifaapp-eks"
    }
  }
}