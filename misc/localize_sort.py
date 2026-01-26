#!/usr/bin/env python3

import ctypes
from functools import cmp_to_key


def build_localized_compare():
    try:
        libobjc = ctypes.cdll.LoadLibrary("/usr/lib/libobjc.A.dylib")
    except OSError:
        return None

    objc_getClass = libobjc.objc_getClass
    objc_getClass.restype = ctypes.c_void_p
    objc_getClass.argtypes = [ctypes.c_char_p]

    sel_registerName = libobjc.sel_registerName
    sel_registerName.restype = ctypes.c_void_p
    sel_registerName.argtypes = [ctypes.c_char_p]

    objc_msgSend_str = ctypes.CFUNCTYPE(
        ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_char_p
    )(("objc_msgSend", libobjc))
    objc_msgSend_cmp = ctypes.CFUNCTYPE(
        ctypes.c_long, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p
    )(("objc_msgSend", libobjc))

    ns_string = objc_getClass(b"NSString")
    sel_string_with_utf8 = sel_registerName(b"stringWithUTF8String:")
    sel_compare = sel_registerName(b"localizedStandardCompare:")

    def compare(a, b):
        ns_a = objc_msgSend_str(ns_string, sel_string_with_utf8, a.encode("utf-8"))
        ns_b = objc_msgSend_str(ns_string, sel_string_with_utf8, b.encode("utf-8"))
        result = objc_msgSend_cmp(ns_a, sel_compare, ns_b)
        if result < 0:
            return -1
        if result > 0:
            return 1
        return 0

    return compare


LOCALIZED_COMPARE = build_localized_compare()


def compare_strings(a: str, b: str) -> int:
    if LOCALIZED_COMPARE:
        return LOCALIZED_COMPARE(a, b)
    return (a > b) - (a < b)


def sort_keys(keys):
    if LOCALIZED_COMPARE:
        return sorted(keys, key=cmp_to_key(LOCALIZED_COMPARE))
    return sorted(keys)


def sort_entries(entries):
    def compare_entries(a, b):
        key_a = a.get("key", "")
        key_b = b.get("key", "")
        result = compare_strings(key_a, key_b)
        if result != 0:
            return result
        comment_a = a.get("comment") or ""
        comment_b = b.get("comment") or ""
        return compare_strings(comment_a, comment_b)

    entries.sort(key=cmp_to_key(compare_entries))
