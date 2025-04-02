#!/usr/bin/env bash
set -ueo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends less fonts-freefont-otf
tlmgr update --self
tlmgr install xetex sourceserifpro sourcesanspro polyglossia fontspec \
  koma-script graphics geometry soul infwarerr etexcmds enumitem xstring roboto \
  extsizes lipsum supertabular cellspace nopageno multirow numprint numspell \
  numnameru datetime2 pgf oberdiek ltxcmds tools hyphen-russian hyperref \
  datetime2-russian
tlmgr path add
# from https://gitlab.com/islandoftex/images/texlive/-/blob/master/Dockerfile
(
  luaotfload-tool -u ||
    true
)
(
  cp -vf "$(
    find /usr/local/texlive -name texlive-fontconfig.conf
  )" /etc/fonts/conf.d/09-texlive-fonts.conf ||
    true
)
fc-cache -fsv
if [ -f "/usr/bin/context" ]; then
  mtxrun --generate
  texlua /usr/bin/mtxrun.lua --luatex --generate
  context --make
  context --luatex --make
fi

# cleanup
apt-get clean
rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/* /root/.cache/pip /files
