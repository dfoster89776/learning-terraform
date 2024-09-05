module "qa" {
    source = "../modules/blog"

    environment = {
        name = "qa"
        network_prefix = "10.1"
    }

    blog_as.min_size = 1
    blog_as.max_size = 2
}