import xml.etree.ElementTree as ET

tree = ET.parse('HRVSpark.xcodeproj/xcshareddata/xcschemes/HRVSpark Watch App Watch App.xcscheme')
root = tree.getroot()

for action in ['BuildAction', 'TestAction', 'LaunchAction', 'ProfileAction']:
    action_element = root.find(action)
    if action_element is not None:
        if action == 'BuildAction':
            entries = action_element.find('BuildActionEntries')
            if entries is not None:
                for entry in entries.findall('BuildActionEntry'):
                    ref = entry.find('BuildableReference')
                    if ref is not None and ref.get('BlueprintName') == 'HRVSpark':
                        entries.remove(entry)
        else:
            runnable = action_element.find('BuildableProductRunnable')
            if runnable is not None:
                ref = runnable.find('BuildableReference')
                if ref is not None and ref.get('BlueprintName') == 'HRVSpark':
                    action_element.remove(runnable)

tree.write('HRVSpark.xcodeproj/xcshareddata/xcschemes/HRVSpark Watch App Watch App.xcscheme')
