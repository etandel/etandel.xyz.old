sitegen = require 'sitegen'
lfs = require 'lfs'


path_join = (p1, p2) ->
    p1 = p1\match '^(.-)/?$'
    p2 = p2\match '^/?(.*)'
    return p1 .. '/' .. p2


is_hidden = (path) -> path\match '^%.'

get_post_index_key = (path) -> path\match '/?(..+).md$'


BLOG_POSTS_ROOT = 'blog/posts/'


add_blog = (add) =>
    for post in lfs.dir BLOG_POSTS_ROOT
        if not is_hidden post
            post_key = get_post_index_key post
            post = path_join BLOG_POSTS_ROOT, post
            target = path_join 'blog/', post_key
            add post, template: 'blog', target: target


    add 'blog/index.md', template: 'blog', target: 'blog/index'


sitegen.create =>
    deploy_to 'ubuntu@etandel.xyz', '/usr/share/nginx/etandel.xyz'
    add 'index.html'

    add_blog self, add

