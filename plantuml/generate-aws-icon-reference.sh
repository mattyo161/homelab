#!/bin/bash
# generate-aws-icon-reference.sh
# Generates a PlantUML markdown reference for all AWS icons

DIST_AZURE="https://raw.githubusercontent.com/plantuml-stdlib/Azure-PlantUML/main/dist"
DIST_AWS="https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist"
API_DIST_AZURE="https://api.github.com/repos/plantuml-stdlib/Azure-PlantUML/contents/dist"
API_DIST_AWS="https://api.github.com/repos/awslabs/aws-icons-for-plantuml/contents/dist"
GH_API_DIST_AZURE="repos/plantuml-stdlib/Azure-PlantUML/contents/dist"
GH_API_DIST_AWS="repos/awslabs/aws-icons-for-plantuml/contents/dist"


DIST="${DIST_AWS}"
API_DIST="${API_DIST_AWS}"
GH_API_DIST="${GH_API_DIST_AWS}"
OUTPUT="aws-icon-reference.md"
OUTPUT="/Users/matt/Library/Mobile Documents/iCloud~md~obsidian/Documents/MOU Notes/Reference/PlantUML - aws-icon-reference.md"

echo "# AWS PlantUML Icon Reference" > "${OUTPUT}"
echo "" >> "${OUTPUT}"

# Get folder list from GitHub API
folders=($(gh api "${GH_API_DIST}" \
  | jq -r '.[] | select(.type=="dir") | .name'))

for folder in "${folders[@]}"; do
  echo "## $folder" >> "${OUTPUT}"
  echo "" >> "${OUTPUT}"

  HEADER="$(cat << EOF
\`\`\`plantuml
@startuml
!define awslib $DIST
!include awslib/AWSCommon.puml
!include awslib/$folder/all.puml

!procedure \$iconRow(\$name)
| %call_user_func("\$" + \$name + "IMG") | \$name | \$%string(\$name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
EOF
)"
  FOOTER="$(cat << EOF
endlegend

@enduml
\`\`\`

EOF
)"

  echo "Getting icons in folder ${folder}" >&2
  # Get icons in folder — quoted, excluding all.puml
  icons=($(gh api "${GH_API_DIST}/${folder}" \
    | jq -r '.[] | select(.name | endswith(".puml")) | .name | select(. != "all.puml") | gsub(".puml";"")'))
  iconnum=0
  for icon in "${icons[@]}"; do
    if [[ $((iconnum % 10)) -eq 0 && $iconnum -gt 0 ]]; then
      echo "$FOOTER" >> "${OUTPUT}"
    fi
    if [[ $((iconnum % 10)) -eq 0 ]]; then
      echo "$HEADER" >> "${OUTPUT}"
    fi
    echo "\$iconRow(\"${icon}\")" >> "${OUTPUT}"
    iconnum=$((iconnum + 1))
  done
  echo "$FOOTER" >> "${OUTPUT}"

  
done

echo "Done! Output: ${OUTPUT}"