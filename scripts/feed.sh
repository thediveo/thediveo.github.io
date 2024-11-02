#!/bin/bash
DOCSDIR="docs"
POSTSDIR="art"
FEEDFILENAME="feed.xml"

BLOGURL="https://thediveo.github.io"

LGRAY="\033[0;37m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"

BOLD="\033[1m"

RESET="\033[0m"

STEP="${CYAN}${BOLD}"
SKIPPED="${LGRAY}"
ACCEPTED="${GREEN}"
SUCCESS="${GREEN}"
NOTE="${LGRAY}"

# https://stackoverflow.com/a/12873723
#
# But note that we finally run "xmllint" that have its own head about single
# quotes in particular.
escape() {
    echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'\''/\&#39;/g'
}

# For each article/post with proper front matter, generate an RSS feed item and
# index it by its creation date (which is the date it was put under git
# control). Please note that the creation timestamp index is in UTC to allow
# proper sorting without getting tripped up by time zones.
#
# Please note that we do proper XML escaping for the title and description data.
echo -e "${STEP}Scanning for posts in ${DOCSDIR}/${POSTSDIR}...${RESET}"
declare -A items
declare -A itemmatters
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
        date=$(LC_TIME="C" date +"%Y-%m-%d %H:%M:%S %z")
    fi

    dateindex=$(LC_TIME="C" date -d "${date}" --utc +"%Y-%m-%d %H:%M:%S")

    basename=${post##*/}
    link="${BLOGURL}/#/${POSTSDIR}/${basename%.*}"
    itemmatters["${dateindex}//link"]="/${POSTSDIR}/${basename%.*}"
    itemmatters["${dateindex}//title"]="${title}"
    itemmatters["${dateindex}//description"]="${title}"

    pubdate=$(LC_TIME="C" date -d "${date}" +"%a, %d %b %Y %H:%M:%S %z")
    echo "$post....$date"
    items["${dateindex}"]="
        <item>
            <title>${title}</title>
            <link>${link}</link>
            <description>${description}</description>
            <pubDate>${pubdate}</pubDate>
            <guid>${link}</guid>
        </item>"

    echo -e "${ACCEPTED}Accepted: ${post} -- ${title}${RESET}"
    echo -e "${NOTE}   dated: ${date} (${dateindex} +0000)${RESET}"
done

# Generate the header part of the RSS feed XML file...
echo -e "${STEP}Generating RSS feed ${DOCSDIR}/${FEEDFILENAME}...${RESET}"
cat <<EOF >"${DOCSDIR}/${FEEDFILENAME}"
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
    <channel>
        <title>TheDiveO's Open Source</title>
        <link>${BLOGURL}</link>
        <atom:link href="${BLOGURL}/${FEEDFILENAME}" rel="self" type="application/rss+xml" />
        <description>Background information on TheDiveO's Open Source works.</description>
EOF

# Emit items by date with the newest coming first; and at the same time keep the
# sorted UTC timestamps in sorteddates so we can use them elsewhere.
sorteddates=()
while IFS= read -r date; do
    sorteddates+=("${date}")
    echo "${items[${date}]}" >>"${DOCSDIR}/${FEEDFILENAME}"
done < <(printf "%s\n" "${!items[@]}" | sort -r) # https://serverfault.com/a/718106

# Properly end the RSS XML.
cat <<EOF >>"${DOCSDIR}/${FEEDFILENAME}"
    </channel>
</rss>
EOF

xmllint --format "${DOCSDIR}/${FEEDFILENAME}" -o "${DOCSDIR}/${FEEDFILENAME}.new"
mv --force "${DOCSDIR}/${FEEDFILENAME}.new" "${DOCSDIR}/${FEEDFILENAME}"

echo -e "${STEP}Generating sidebar post items...${RESET}"
postitems=()
for date in "${sorteddates[@]}"; do
    title="${itemmatters[${date}//title]}"
    link="${itemmatters[${date}//link]}"
    echo -e "${NOTE}   ${title} ⇢ ${link}"
    postitems+=("  * [${title}](${link})")
done

echo -e "${SUCCESS}Success.${RESET}"
