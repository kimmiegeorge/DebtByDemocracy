'''
Pull OS document info from index
want to loop through daily index files, pull documents with document type = OS
save document identifying information to parse PDFs
'''

import xml.etree.ElementTree as ET
import os

'/Volumes/SZ/MSRB_dropbox/2009/PM.2009.06.01.IndexData'
# Parse the XML file
# Path to the directory containing the XML files

directory = '/Volumes/SZ/MSRB_dropbox/2009/PM.2009.06.02.IndexData/'

document_identifiers = []

count = 0

# Loop through all files in the directory
for filename in os.listdir(directory):
    if filename.endswith('.xml'):
        tree = ET.parse(os.path.join(directory, filename))
        root = tree.getroot()

        for child in root:
            for sub1 in child:
                # first, look for document element and pull classification
                if sub1.tag.endswith('Document'):
                    document_type = sub1.attrib.get('DocumentType')
                    document_identifier = sub1.attrib.get('DocumentIdentifier')
                    # if official statement, continue to pull file identifier
                    if document_type == 'OfficialStatement':
                        for sub2 in sub1:
                            if sub2.tag.endswith('UnderlyingFiles'):
                                for sub3 in sub2:
                                    file_id = sub3.attrib.get('FileIdentifier')
                                    document_identifiers.append(file_id)


    count += 1
    if count == 100:
        break

print("Document Identifiers with DocumentType 'OfficialStatement':")
for identifier in document_identifiers:
    print(identifier)

for child in root:
    print(child.tag, child.attrib)
    for subchild in child:
        print(subchild.attrib)


file_identifiers = []
# Recursive function to search for FileIdentifier
def find_file_identifier(element):
    for sub1 in element:
        if sub1.tag.endswith('Document'):
            for sub2 in sub1:
                if sub2.tag.endswith('UnderlyingFiles'):
                    for sub3 in sub2:
                        print(sub3.attrib)

        # Start searching from the root element


find_file_identifier(root)


def print_element(element, indent=''):
    print(f"{indent}Element: {element.tag}")
    for key, value in element.attrib.items():
        print(f"{indent}  Attribute: {key} = {value}")
    if element.text:
        print(f"{indent}  Text: {element.text}")
    for child in element:
        print_element(child, indent + '    ')

        # Start printing from the root element


print_element(root)

