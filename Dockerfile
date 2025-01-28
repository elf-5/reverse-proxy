FROM mcr.microsoft.com/dotnet/sdk:9.0 AS base

WORKDIR /src

ARG NUGET_AUTH_TOKEN
ENV NUGET_AUTH_TOKEN=${NUGET_AUTH_TOKEN}
RUN wget -qO- https://raw.githubusercontent.com/Microsoft/artifacts-credprovider/master/helpers/installcredprovider.sh | bash
RUN wget -qO- https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 8.0 --install-dir /usr/share/dotnet


FROM base AS development
# needed for NTLM auth with HttpClient
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \ 
    && apt-get update && apt-get install -y --no-install-recommends gss-ntlmssp 

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    apt-get install -y ssh curl 

# Use to ensure we are running the same version of node that we use in the frontend apps
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    apt-get install -y nodejs

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    apt-get install -y sqlite3

# NOTE we do not run dotnet restore for the development image because it would be installed as root
# and we want it to be installed as CONTAINER_USERNAME when the container is running

FROM development as devcontainer

RUN dotnet dev-certs https --trust

RUN curl https://packages.microsoft.com/keys/microsoft.asc | tee /etc/apt/trusted.gpg.d/microsoft.asc
RUN curl https://packages.microsoft.com/config/debian/11/prod.list > /etc/apt/sources.list.d/mssql-release.list


ARG USERNAME
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME
RUN apt-get update \
    && apt-get install -y sudo
RUN echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME 

RUN ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev curl

ENV PATH="$PATH:/home/$USERNAME/.dotnet/tools/:/opt/mssql-tools18/bin"

RUN rm -rf /var/lib/apt/lists/*



