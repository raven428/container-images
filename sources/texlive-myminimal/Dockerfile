# kics-scan disable=b03a748a-542d-44f4-bb86-9199ab4fd2d5,f45ea400-6bbe-4501-9fc7-1c3d75c32067,965a08d7-ef86-4f14-8792-4a3b2098937e,fd54f200-402c-4333-a5a4-36ef6709af2f
# until supertable fix:
  FROM registry.gitlab.com/islandoftex/images/texlive:TL2025-2025-04-27-minimal
# FROM registry.gitlab.com/islandoftex/images/texlive:latest-minimal
COPY files /files
RUN /files/install.sh
