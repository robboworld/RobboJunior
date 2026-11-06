#!/usr/bin/env python3
"""Rewrites a copied profile for another home directory: the WebSQL rows hold absolute paths.

Usage: move-profile.py <RobboJunior profile> <old home> <new home>
"""

import glob
import os
import sqlite3
import sys


def main():
    profile, old_home, new_home = sys.argv[1:4]
    for path in glob.glob(os.path.join(profile, 'databases', 'file__0', '*')):
        database = sqlite3.connect(path)
        tables = [row[0] for row in database.execute(
            "select name from sqlite_master where type = 'table' and name not like 'sqlite_%' and name != '__WebKitDatabaseInfoTable__'")]
        for table in tables:
            columns = [row[1] for row in database.execute(f'pragma table_info("{table}")')]
            for column in columns:
                database.execute(f'update "{table}" set "{column}" = replace("{column}", ?, ?) '
                                 f'where typeof("{column}") = \'text\'', (old_home, new_home))
        database.commit()
        database.close()


main()
