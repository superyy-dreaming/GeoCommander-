#!/bin/zsh
set -e
cd "${0:A:h}"
GEO_ENGINE="${GEO_GODOT:-$HOME/.local/share/geocommander/tools/4.7.2/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$GEO_ENGINE" ]]; then
  print '未找到 Godot 4.7.2。请通过 GEO_GODOT 指定引擎路径，或用 Godot 编辑器导入 project.godot。'
  exit 1
fi
exec "$GEO_ENGINE" --path "$PWD" "$@"
