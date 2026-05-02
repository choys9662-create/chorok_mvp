import re
import os

file_path = 'lib/features/home/screen/home_screen.dart'
with open(file_path, 'r') as f:
    lines = f.readlines()

def extract_block_by_regex(start_regex):
    start_idx = -1
    for i, line in enumerate(lines):
        if re.search(start_regex, line):
            start_idx = i
            break
    if start_idx == -1: return []
    
    # Simple brace matching
    brace_count = 0
    in_block = False
    end_idx = start_idx
    for i in range(start_idx, len(lines)):
        line = lines[i]
        brace_count += line.count('{') - line.count('}')
        if line.count('{') > 0: in_block = True
        if in_block and brace_count == 0:
            end_idx = i
            break
    
    block = lines[start_idx:end_idx+1]
    # Remove from lines
    del lines[start_idx:end_idx+1]
    return block

def extract_variables(var_names):
    extracted = []
    for var in var_names:
        start_idx = -1
        for i, line in enumerate(lines):
            if line.startswith(var):
                start_idx = i
                break
        if start_idx != -1:
            # find end (semicolon)
            end_idx = start_idx
            for i in range(start_idx, len(lines)):
                if ';' in lines[i]:
                    end_idx = i
                    break
            extracted.extend(lines[start_idx:end_idx+1])
            del lines[start_idx:end_idx+1]
    return extracted

# 1. FeedHighlightSection
feed_highlight = extract_block_by_regex(r'^class _HighlightSentence')
feed_highlight += extract_block_by_regex(r'^class _FeedHighlightSection')
feed_highlight += extract_block_by_regex(r'^class _HighlightCard')

with open('lib/features/home/widget/feed_highlight_section.dart', 'w') as f:
    f.write("import 'package:flutter/material.dart';\n")
    f.write("import '../../../core/theme/app_theme.dart';\n")
    f.write("import '../../../core/constants/app_constants.dart';\n")
    f.write("import '../../../shared/widgets/chorok_card.dart';\n")
    f.write("import 'package:go_router/go_router.dart';\n")
    f.write("import 'package:flutter/services.dart';\n")
    f.write("import 'package:figma_squircle/figma_squircle.dart';\n\n")
    f.write("".join(feed_highlight).replace('_FeedHighlightSection', 'FeedHighlightSection').replace('_HighlightCard', 'HighlightCard').replace('_HighlightSentence', 'HighlightSentence'))

# 2. TimeCapsuleSection
time_capsule = extract_block_by_regex(r'^class _TimeCapsuleSection')
with open('lib/features/home/widget/time_capsule_section.dart', 'w') as f:
    f.write("import 'package:flutter/material.dart';\n")
    f.write("import 'package:flutter_riverpod/flutter_riverpod.dart';\n")
    f.write("import '../../../core/theme/app_theme.dart';\n")
    f.write("import '../../../shared/models/isar/isar_choseo.dart';\n")
    f.write("import '../../../shared/providers/library_provider.dart';\n")
    f.write("import '../../../shared/repositories/book_repository.dart';\n")
    f.write("import 'package:flutter/services.dart';\n")
    f.write("import 'package:go_router/go_router.dart';\n")
    f.write("import '../../../core/constants/app_constants.dart';\n")
    f.write("import 'package:figma_squircle/figma_squircle.dart';\n\n")
    
    # We need _timeCapsuleProvider. Let's extract it from lines
    provider_idx = -1
    for i, l in enumerate(lines):
        if l.startswith('final _timeCapsuleProvider'):
            provider_idx = i
            break
    if provider_idx != -1:
        f.write("".join(lines[provider_idx:provider_idx+3]))
        del lines[provider_idx:provider_idx+3]
    f.write("\n")
    f.write("".join(time_capsule).replace('_TimeCapsuleSection', 'TimeCapsuleSection').replace('_timeCapsuleProvider', 'timeCapsuleProvider'))

# Write updated home_screen.dart back for now
with open(file_path, 'w') as f:
    f.writelines(lines)

