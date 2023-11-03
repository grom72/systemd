#!/usr/bin/env python3

import re
import json

STACK_USAGE_FILE='stats/stack-usage-libudev-basic.a.p.txt'
CALL_STACK_FILE='stats/cflow.txt'
NOT_CALLED_WHITELIST_FILE='stats/not_called_whitelist.json'

STATS_PATH='stats/'

API = [
"udev_new",
"udev_queue_new",
"udev_queue_get_queue_is_empty",
"udev_unref",
"udev_queue_unref"
]

DEAD_END = [
        'log_assert',
        'log_assert_failed'
]

def dump(var, name):
        path = STATS_PATH+name
        with open(f"{path}.json", "w") as outfile:
                json.dump(var, outfile, indent = 4)

def load_stack_usage():
        funcs = {}
        with open(STACK_USAGE_FILE, 'r') as file:
                for line in file:
                        # 8432 out_common : src/nondebug/libpmem/out.su:out.c dynamic,bounded
                        # found = re.search("([0-9]+) ([a-zA-Z0-9_]+)(.[a-z0-9.]+)* : [a-z0-9\-.:/_]+ ([a-z,]+)", line)
                        found = re.search("([0-9]+) ([a-zA-Z0-9_]+)(.[a-z0-9.]+)* ([a-z,]+)", line)
                        # print('{} {} {}'.format(found.group(1), found.group(2), found.group(3)))
                        if found:
                                funcs[found.group(2)] = {'size': found.group(1), 'type': found.group(4)}
                        else:
                                # An unexpected line format
                                print(line)
                                exit(1)
        return funcs

def load_call_stack():
        calls = {}
        callers = []
        with open(CALL_STACK_FILE, 'r') as file:
                for line in file:
                        line_copy = line
                        level = 0
                        while line[0] == ' ':
                                level += 1
                                line = line[4:]
# pmem_memset_persist() <void *pmem_memset_persist (void *pmemdest, int c, size_t len) at pmem.c:731>:
                        found = re.search("^([a-zA-Z0-9_]+)\(\)", line)
                        if not found:
                                # An unexpected line format
                                print(line_copy)
                                exit(1)
                        func = found.group(1)
                        callers.insert(level, func)
                        if level == 0:
                                continue
                        callee = func
                        caller = callers[level - 1]
                        if caller == "pmem":
                                print(line_copy)
                                exit(1)
                        if caller in calls.keys():
                                calls[caller].append(callee)
                        else:
                                calls[caller] = [callee]
        # remove duplicates
        calls_unique = {}
        for k, v in calls.items():
                v_unique = list(set(v))
                calls_unique[k] = v_unique
        return calls_unique

def dict_extend(dict_, key, values):
        if key not in dict_.keys():
                dict_[key] = values
        else:
                dict_[key].extend(values)
        return dict_

def inlines(calls):
        return calls

def function_pointers(calls):
        return calls

def is_reachable(func, calls):
        callers = [func]
        while len(callers) > 0:
                callers_new = []
                for callee in callers:
                        for k, v in calls.items():
                                if callee not in v:
                                        continue
                                if k not in API:
                                        callers_new.append(k)
                                return True
                callers = callers_new
        print(func)
        return False

def api_callers(func, calls):
        callers = [func]
        visited = [func] # loop breaker
        apis = []
        while len(callers) > 0:
                callers_new = []
                for callee in callers:
                        for k, v in calls.items():
                                # this caller does not call this callee
                                if callee not in v:
                                        continue
                                # it is part of the API
                                if k in visited:
                                        continue
                                if k in API or k in DEAD_END:
                                        apis.append(k)
                                else:
                                        callers_new.append(k)
                                        visited.append(k)
                callers = list(set(callers_new))
                # print(callers)
                # if len(apis) > 0 and len(callers) > 0:
                #         exit(1)
        # if len(apis) == 0:
        #         print(func)
        # assert(len(apis) > 0)
        return apis

def validate(funcs, calls):
        all_callees = []
        for _, v in calls.items():
                all_callees.extend(v)
        all_callees = list(set(all_callees))
        # dump(all_callees, 'all_callees')

        with open(NOT_CALLED_WHITELIST_FILE, 'r') as file:
                whitelist = json.load(file)

        # All known functions are expected to be called at least once
        not_called = []
        for k, v in funcs.items():
                if k in all_callees:
                        continue
                if k in whitelist:
                        continue
                if k in API:
                        continue
                if int(v['size']) <= 128:
                        continue
                not_called.append(k)
        # not_called.sort()
        dump(not_called, 'not_called')
        # assert(len(not_called) == 0)

        # for callee in all_callees:
        #         assert(is_reachable(callee, calls))

        # All mem(move|set) functions are expected to be tracked back to pmem_mem* API calls
        no_api_connection = {}
        for k, v in funcs.items():
        # for k in ['prealloc']:
                if k in whitelist or k in DEAD_END or k in API:
                        continue
                if k in API:
                        continue
                # too complex, ignore
                # if k in ['out_common']:
                #         continue
                # print(k)
                callers = api_callers(k, calls)
                # valid = False
                # for caller in callers:
                #         if re.search("^pmem_mem", caller):
                #                 valid = True
                #                 break
                # if not valid:
                #         print(k)
                if int(v['size']) <= 32: # there is too many of them
                        continue
                if len(callers) == 0:
                        no_api_connection[k] = v['size']
        dump(no_api_connection, 'no_api_connection')
        # assert(len(no_api_connection) == 0)

def generate_call_stacks(func, funcs, rcalls):
        call_stacks = [
                {
                        'stack': [func],
                        'size': int(funcs[func]['size']) if func in funcs.keys() else 0
                }
        ]
        # the main loop
        while True:
                call_stacks_new = []
                call_stacks_new_end = []
                for call_stack in call_stacks:
                        callee = call_stack['stack'][0]
                        if callee in API:
                                call_stacks_new_end.append(call_stack)
                                continue
                        if callee not in rcalls.keys():
                                call_stacks_new_end.append(call_stack)
                                continue
                        for caller in rcalls[callee]:
                                if call_stack['stack'].count(caller) == 2:
                                        continue # loop breaker
                                if caller in funcs.keys():
                                        caller_stack_size = int(funcs[caller]['size'])
                                else:
                                        caller_stack_size = 0
                                call_stacks_new.append({
                                        'stack': [caller] + call_stack['stack'],
                                        'size': call_stack['size'] + caller_stack_size
                                })
                if len(call_stacks_new) == 0:
                        break
                call_stacks = call_stacks_new + call_stacks_new_end
        return call_stacks

# check if a is a substack of b
def is_substack(a, b):
        if len(a['stack']) >= len(b['stack']):
                return False
        for i in range(len(a['stack'])):
                if a['stack'][i] != b['stack'][i]:
                        return False
        return True

def call_stacks_reduce(call_stacks):
        ret_call_stacks = []
        for i in range(len(call_stacks)):
                a = call_stacks[i]
                substack = False
                for j in range(len(call_stacks)):
                        if i == j:
                                continue
                        b = call_stacks[j]
                        if is_substack(a, b):
                                substack = True
                                break
                if not substack:
                        ret_call_stacks.append(a)
        return ret_call_stacks

def call_stack_key(e):
        return e['size']

def generate_all_call_stacks(funcs, calls):
        with open(NOT_CALLED_WHITELIST_FILE, 'r') as file:
                whitelist = json.load(file)
        # preparing a reverse call dictionary
        rcalls = {}
        for caller, callees in calls.items():
                for callee in callees:
                        rcalls = dict_extend(rcalls, callee, [caller])
        # dump(rcalls, 'rcalls')
        print("Reverse call dictionary - done")

        call_stacks = []
        for func in rcalls.keys():
        # for func in ['VALGRIND_ANNOTATE_NEW_MEMORY']:
                if func == 'LOG':
                        continue
                if func in whitelist:
                        continue
                if func in calls.keys():
                        continue
                print(f"Generating call stacks ending at - {func}")
                call_stacks.extend(generate_call_stacks(func, funcs, rcalls))
        # call_stacks = call_stacks_reduce(call_stacks)
        print(len(call_stacks))
        call_stacks.sort(reverse=True, key=call_stack_key)
        dump(call_stacks, 'call_stacks_all')

        # Filter out daxctl-related
        #call_stacks_udev = list(filter(lambda call_stack: re.search('^udev_', call_stack['stack'][0]), call_stacks))
        # call_stacks = list(filter(lambda call_stack: not (
        #         (call_stack['stack'][0] in ['pmemobj_create', 'pmemobj_open', 'pmemobj_alloc', 'pmemobj_free', 'pmemobj_reserve', 'pmemobj_root', 'pmemobj_tx_xalloc'] and
        #          ('pmem2_region_namespace' in call_stack['stack'] or 'pmem2_device_dax_size' in call_stack['stack'] or 'pmem2_device_dax_alignment' in call_stack['stack'])) or
        #         (call_stack['stack'][0] in ['pmemobj_open', 'pmemobj_create', 'pmemobj_close'] and ('pmem2_get_region_id' in call_stack['stack']))
        #         ), call_stacks))
        #print(len(call_stacks_udev))
        #dump(call_stacks_udev, 'call_stacks_udev')
        # call_stacks = list(filter(lambda call_stack: re.search('^pmem_(mem|persist|flush|drain)', call_stack['stack'][-1]), call_stacks))
        # call_stacks = list(filter(lambda call_stack: not (
        #         (call_stack['stack'][0] in ['pmemobj_create', 'pmemobj_open', 'pmemobj_alloc', 'pmemobj_root', 'pmemobj_free'] and 'palloc_operation' in call_stack['stack']) or
        #         ('ulog_entry_buf_create' in call_stack['stack']) or
        #         ('heap_init' in call_stack['stack'])
        #         ), call_stacks))
        # print(len(call_stacks))
        # call_stacks.sort(reverse=True, key=call_stack_key)
        # dump(call_stacks, 'call_stacks_pmem_ops')

def main():
        funcs = load_stack_usage()
        dump(funcs, 'funcs')
        calls = load_call_stack()
        # calls = inlines(calls)
        # calls = function_pointers(calls)
        dump(calls, 'calls')
        validate(funcs, calls)
        print("Validation - done")

        generate_all_call_stacks(funcs, calls)

if __name__ == '__main__':
        main()
