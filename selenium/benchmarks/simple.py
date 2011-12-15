#!/usr/bin/env python

import unittest
from selenium import webdriver

LOGFILE = "../../logs"


class TestEcomomBenchmarksSimple(unittest.TestCase):
    '''produce a log with simple benchmarks'''

    def setUp(self):
        self.browser = webdriver.Firefox()

    def test_cart_loading(self):
        self.browser.get('http://www.ubuntu.com/')
