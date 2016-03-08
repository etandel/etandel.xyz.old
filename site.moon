sitegen = require 'sitegen'


sitegen.create =>
    add 'index.html'

    add 'blog/posts/hello.md', template: 'blog', target: 'blog/hello'

