import os
import requests
from bs4 import BeautifulSoup, SoupStrainer

def get_links(html):
    """Returns a list of links parsed from an OME downloads webpage"""
    
    soup = BeautifulSoup(html, "html.parser", parse_only=SoupStrainer("td"))
    links = [tag.string for tag in soup.find_all('a')]

    # return all but the first link (which is the parent directory)
    return links[1:]

def get_files(url, output_path):
    """Recursively downloads files from a OME downloads webpage to the output path"""

    print(f"{url}... ", end='')
    r = requests.get(url, stream=True)

    if r.status_code != requests.codes.ok:
        print(f"failed with status code {r.status_code}")
        return
    
    if "html" in r.headers['Content-Type']:
        # if the content is html, then it must be a directory
        if not os.path.exists(output_path):
            os.makedirs(output_path)
            print("made directory")
        else:
            print("directory exists")

        # parse html for links
        links = get_links(r.content)

        # recursively call function to download all links
        for link in links:
            get_files(r.url + link, os.path.join(output_path, link))
    else:
        # if the content is not html, then it must be a file
        if not os.path.exists(output_path):
            with open(output_path, 'wb') as f:
                f.write(r.content)
                print("downloaded")
        else:
            print("skipping")

    return

if __name__ == "__main__":
    base_url = "https://downloads.openmicroscopy.org/images/Imaris-IMS"
    output_path = "~/Desktop/sample-images"

    get_files(base_url, os.path.expanduser(output_path))