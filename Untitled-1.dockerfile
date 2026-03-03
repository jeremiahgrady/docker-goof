#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

ARG BUILD_NUMBER=local
ARG GIT_REV=unknown

FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
ARG BUILD_NUMBER
ARG GIT_REV
WORKDIR /src

COPY [".nuget/NuGet.Config", "/root/.nuget/NuGet/"]
COPY ["Directory.Packages.props", "./"]
COPY ["src/Tangram/Tangram.csproj", "src/Tangram/"]
COPY ["src/Tangram.Infrastructure/Tangram.Infrastructure.csproj", "src/Tangram.Infrastructure/"]
COPY ["src/Tangram.Domain/Tangram.Domain.csproj", "src/Tangram.Domain/"]
COPY ["src/Tangram.Crosscutting/Tangram.Crosscutting.csproj", "src/Tangram.Crosscutting/"]
COPY ["src/Tangram.Domain.Services/Tangram.Domain.Services.csproj", "src/Tangram.Domain.Services/"]
COPY ["src/Tangram.Application/Tangram.Application.csproj", "src/Tangram.Application/"]

RUN dotnet restore "src/Tangram/Tangram.csproj"

COPY . .
WORKDIR "/src/src/Tangram"
RUN dotnet build "Tangram.csproj" -c Release -o /app/build \
    /p:InformationalVersion=${BUILD_NUMBER}-${GIT_REV}

FROM build AS publish
ARG BUILD_NUMBER
ARG GIT_REV
RUN dotnet publish "Tangram.csproj" -c Release -o /app/publish \
    /p:UseAppHost=false \
    /p:InformationalVersion=${BUILD_NUMBER}-${GIT_REV}

FROM base AS final
WORKDIR /app

# Upgrade packages to fix security vulnerabilities
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libicu67=67.1-7+deb11u1 \
        libgnutls30=3.7.1-5+deb11u8 \
        libpam0g=1.4.0-9+deb11u2 \
        libpam-modules-bin=1.4.0-9+deb11u2 \
        libpam-runtime=1.4.0-9+deb11u2 \
        gpgv=2.2.27-2+deb11u3 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=publish /app/publish .

LABEL build.number="${BUILD_NUMBER}" \
      build.git.revision="${GIT_REV}"

ENTRYPOINT ["dotnet", "Tangram.dll"]
