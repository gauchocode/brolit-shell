#!/usr/bin/env python3
"""Strict offline yq test double for JSON (a YAML subset) fixtures only.

Not a YAML parser or evidence of compatibility with real yq/borgmatic.
Unknown expressions fail instead of silently approving untested operations.
"""
import json
import os
import re
import sys

args = sys.argv[1:]
mutate = args[0] == '-i'
if args[0] in ('-i', '--exit-status'):
    args.pop(0)
expression, filename = args
if os.environ.get('FAKE_YQ_COUNT'):
    countfile = os.environ['FAKE_YQ_COUNT']
    try:
        count = int(open(countfile).read()) + 1
    except (FileNotFoundError, ValueError):
        count = 1
    with open(countfile, 'w') as stream:
        stream.write(str(count))
    if str(count) == os.environ.get('FAKE_YQ_FAIL_AT'):
        print('SECRET_CANARY failed mutation', file=sys.stderr)
        sys.exit(1)
    if str(count) == os.environ.get('FAKE_YQ_SKIP_AT'):
        sys.exit(0)
with open(filename) as stream:
    data = json.load(stream)
constants = data.get('constants')
if constants is None:
    constants = {}
    if mutate:
        data['constants'] = constants
if mutate:
    if expression.startswith('.repositories = [.repositories['):
        index = int(re.search(r'\[(\d+)\]', expression).group(1))
        data['repositories'] = [data['repositories'][index]]
    else:
        for part in expression.split(' | '):
            if part == '.repositories = []':
                data['repositories'] = []
            elif part == 'del(.constants.database)':
                constants.pop('database', None)
            elif re.fullmatch(r'\.constants\.\w+ = strenv\(\w+\)', part):
                key, value = re.fullmatch(r'\.constants\.(\w+) = strenv\((\w+)\)', part).groups()
                constants[key] = os.environ[value]
            elif part.startswith('.repositories += '):
                data['repositories'].extend(json.loads(part[len('.repositories += '):]))
            else:
                raise ValueError('Unsupported mutation: ' + part)
    with open(filename, 'w') as stream:
        json.dump(data, stream)
elif expression == '.repositories | length':
    print(len(data.get('repositories', [])))
else:
    # Evaluate the supplied comparisons, not a hardcoded intended outcome.
    # In particular missing/null != "" is true, just as in real yq; exact
    # equality to strenv(...) is what must reject missing/null/placeholders.
    def operand(token):
        token = token.strip()
        if token == '(.repositories | length)':
            return len(data.get('repositories', []))
        match = re.fullmatch(r'\(\.constants\.(\w+) \| tag\)', token)
        if match:
            value = constants.get(match[1])
            return {str: '!!str', int: '!!int', float: '!!float', bool: '!!bool', list: '!!seq', dict: '!!map', type(None): '!!null'}[type(value)]
        match = re.fullmatch(r'\.constants\.(\w+)', token)
        if match:
            return constants.get(match[1])
        match = re.fullmatch(r'\.repositories\[(\d+)\].path', token)
        if match:
            index = int(match[1])
            return data['repositories'][index].get('path') if index < len(data['repositories']) else None
        match = re.fullmatch(r'(strenv|env)\((\w+)\)', token)
        if match:
            value = os.environ.get(match[2], '')
            return value if match[1] == 'strenv' else json.loads(value)
        return json.loads(token)

    results = []
    for comparison in expression.split(' and '):
        if comparison.startswith('(') and not comparison.startswith('(.repositories | length)'):
            assert comparison.endswith(')'), comparison
            comparison = comparison[1:-1]
        match = re.fullmatch(r'(.+) (==|!=) (.+)', comparison)
        if not match:
            raise ValueError('Unsupported query: ' + comparison)
        left, operator, right = match.groups()
        equal = operand(left) == operand(right)
        results.append(equal if operator == '==' else not equal)
    sys.exit(0 if all(results) else 1)
