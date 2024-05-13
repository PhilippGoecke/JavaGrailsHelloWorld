docker build --no-cache --rm -f Containerfile -t grails:demo .
docker run --interactive --tty -p 8000:8000 grails:demo
echo "browse http://localhost:8000/greeting/index"
