sitegen = require 'sitegen'
lfs = require 'lfs'


BLOG_POSTS_ROOT = 'blog/posts/'


add_blog = (add) =>
    for post in lfs.dir BLOG_POSTS_ROOT
        if not post\match '^%.'
            post = BLOG_POSTS_ROOT .. post
            target_name = post\match '^.+/(..-).md$'
            add post, template: 'blog', target: 'blog/'..target_name


    add 'blog/index.md', template: 'blog', target: 'blog/index'


sitegen.create =>
    deploy_to 'ubuntu@etandel.xyz', '/usr/share/nginx/etandel.xyz'
    add 'index.html'

    add_blog self, add

