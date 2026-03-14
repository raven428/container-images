#!/usr/bin/env bash
set -ueo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends fonts-freefont-otf less
_tl2024_repos=(
  'https://ftp.math.utah.edu/pub/tex/historic/systems/texlive/2024/tlnet-final/'
  'https://ftp.tu-chemnitz.de/pub/tug/historic/systems/texlive/2024/tlnet-final/'
  'https://pi.kwarc.info/historic/systems/texlive/2024/tlnet-final/'
  'https://mirrors.tuna.tsinghua.edu.cn/tex-historic-archive/systems/texlive/2024/tlnet-final/'
  'https://mirror.nju.edu.cn/tex-historic/systems/texlive/2024/tlnet-final/'
)
_repo_set=false
for _repo in "${_tl2024_repos[@]}"; do
  if tlmgr option repository "$_repo" && tlmgr update --self; then
    _repo_set=true
    break
  fi
done
if [[ "$_repo_set" == false ]]; then
  echo 'Error: All TeX Live repositories are unreachable' >&2
  exit 1
fi
tlmgr update --all
tlmgr install xetex sourceserifpro sourcesanspro polyglossia fontspec \
  koma-script graphics geometry soul infwarerr etexcmds enumitem xstring roboto \
  extsizes lipsum supertabular cellspace nopageno multirow numprint numspell \
  numnameru datetime2 pgf oberdiek ltxcmds tools hyphen-russian hyperref \
  datetime2-russian pdfpages pdflscape adjustbox
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
