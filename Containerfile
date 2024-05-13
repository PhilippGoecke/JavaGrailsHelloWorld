FROM debian:bookworm-slim

RUN DEBIAN_FRONTEND=noninteractive apt update && DEBIAN_FRONTEND=noninteractive apt upgrade -y \
  # install dependencies
  && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends curl wget unzip zip \
  # install OpenJDK CA certificates dependencies
  && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends ca-certificates p11-kit \
  # make image smaller
  && rm -rf "/var/lib/apt/lists/*" \
  && rm -rf /var/cache/apt/archives \
  && rm -rf /tmp/* /var/tmp/*

ENV JAVA_HOME /usr/local/openjdk-17
ENV PATH $JAVA_HOME/bin:$PATH
ENV LANG C.UTF-8
ENV JAVA_VERSION 17

RUN set -eux; \
  downloadUrl='https://download.oracle.com/java/17/latest/jdk-17_linux-x64_bin.tar.gz'; \
  downloadSha256='62f12f52306217ec80bdc6ad0bdc627824b584d4d96c56976215f0167d92a322'; \
  wget --progress=dot:giga -O openjdk.tgz "$downloadUrl"; \
  echo "$downloadSha256 *openjdk.tgz" | sha256sum --strict --check -; \
  mkdir -p "$JAVA_HOME"; \
  tar --extract \
    --file openjdk.tgz \
    --directory "$JAVA_HOME" \
    --strip-components 1 \
    --no-same-owner; \
  rm openjdk.tgz*; \
  { \
    echo '#!/usr/bin/env bash'; \
    echo 'set -Eeuo pipefail'; \
    echo 'trust extract --overwrite --format=java-cacerts --filter=ca-anchors --purpose=server-auth "$JAVA_HOME/lib/security/cacerts"'; \
  } > /etc/ca-certificates/update.d/docker-openjdk; \
  chmod +x /etc/ca-certificates/update.d/docker-openjdk; \
  /etc/ca-certificates/update.d/docker-openjdk; \
  find "$JAVA_HOME/lib" -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf; \
  ldconfig; \
  java -Xshare:dump; \
  fileEncoding="$(echo 'System.out.println(System.getProperty("file.encoding"))' | jshell -s -)"; [ "$fileEncoding" = 'UTF-8' ]; rm -rf ~/.java; \
  javac --version; \
  java --version

RUN curl -s https://get.sdkman.io | bash
SHELL ["/bin/bash", "-c"]
RUN source "$HOME/.sdkman/bin/sdkman-init.sh" \
  && sdk version \
  && echo $PATH

RUN source "$HOME/.sdkman/bin/sdkman-init.sh" \
  && sdk install grails \
  && grails --version

WORKDIR /app

RUN source "$HOME/.sdkman/bin/sdkman-init.sh" \
  && grails create-app helloworld

WORKDIR /app/helloworld

RUN source "$HOME/.sdkman/bin/sdkman-init.sh" \
  && grails create-controller greeting \
  && sed -i 's/def index() {/def index() {\n    render "HelloWorld"/g' grails-app/controllers/helloworld/GreetingController.groovy

EXPOSE 8000

CMD ./gradlew bootRun -Dgrails.server.port=8000
