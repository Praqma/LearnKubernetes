#!/bin/sh

echo "<html>
<body>
<h1>Welcome to Docker</h1>
Please... behave.
</body>
</html>" > /usr/share/nginx/html/index.html

exec "$@"
