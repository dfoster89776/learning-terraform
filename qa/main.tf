module "qa" {
    source = "../modules/blog"

    environment = {
        name = "qa"
        network_prefix = "10.1"
    }

    asg.min_size = 1
    asg.max_size = 1
}