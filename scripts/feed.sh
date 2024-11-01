#!/bin/bash
DOCSDIR="docs"
POSTSDIR="art"
FEEDFILENAME="feed.xml"

BLOGURL="https://thediveo.github.io"

LGRAY="\033[0;37m"
GREEN="\033[0;32m"
RESET="\033[0m"

SKIPPED=${LGRAY}
ACCEPTED=${GREEN}
SUCCESS=${GREEN}
NOTE=${LGRAY}

# https://stackoverflow.com/a/12873723
#
# But note that we finally run "xmllint" that have its own head about single
# quotes in particular.
escape() {
    echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'\''/\&#39;/g'
}

# Generate the header part of the RSS feed XML file...
cat <<EOF >"${DOCSDIR}/${FEEDFILENAME}"
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
    <channel>
        <title>TheDiveO's Open Source</title>
        <link>${BLOGURL}</link>
        <atom:link href="${BLOGURL}/${FEEDFILENAME}" rel="self" type="application/rss+xml" />
        <description>Background information on TheDiveO's Open Source works.</description>
EOF

# For each article/post with proper front matter, generate an RSS feed item and
# index it by its creation date (which is the date it was put under git
# control).
#
# Please note that we do proper XML escaping for the title and description data.
declare -A items
for post in "${DOCSDIR}/${POSTSDIR}"/*.md; do
    title=$(yq --front-matter=extract '.title' "${post}" 2>/dev/null)
    description=$(yq --front-matter=extract '.description' "${post}" 2>/dev/null)
    if [[ -z "$title" || -z "$description" ]]; then
        echo -e "${SKIPPED}Skipping: ${post}${RESET}"
        continue
    fi

    title=$(escape "${title}")
    description=$(escape "${description}")
    date=$(git log --format="%ci" --diff-filter=A -- "${post}" | head -n 1)
    if [ -z "${date}" ]; then
        date=$(LC_TIME="C" date +"%a, %d %b %Y %H:%M:%S %z")
    fi

    basename=${post##*/}
    link="${BLOGURL}/#/${POSTSDIR}/${basename%.*}"
    pubdate=$(LC_TIME="C" date -d "${date}" +"%a, %d %b %Y %H:%M:%S %z")
    echo "$post....$date"
    items[${date}]="
        <item>
            <title>${title}</title>
            <link>${link}</link>
            <description>${description}</description>
            <pubDate>${pubdate}</pubDate>
            <guid>${link}</guid>
        </item>"

    echo -e "${ACCEPTED}Accepted: ${post} -- ${title}${RESET}"
    echo -e "${NOTE}   dated: ${date}${RESET}"
done

# Emit items by date with the newest coming first...
printf "%s\n" "${!items[@]}" | sort -r | while IFS= read -r date; do
    echo "${items[$date]}" >>"${DOCSDIR}/${FEEDFILENAME}"
done

# Properly end the RSS XML.
cat <<EOF >>"${DOCSDIR}/${FEEDFILENAME}"
    </channel>
</rss>
EOF

xmllint --format "${DOCSDIR}/${FEEDFILENAME}" -o "${DOCSDIR}/${FEEDFILENAME}.new"
mv --force "${DOCSDIR}/${FEEDFILENAME}.new" "${DOCSDIR}/${FEEDFILENAME}"

echo -e "${SUCCESS}Success.${RESET}"
