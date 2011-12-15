## tests

this project contains automted tests for the ecomom.com website.


## setup
prerequtisites:

  *  python
  *  virtualenv/virtualenvwrapper

for python stuff, i reccomend using [virtualenv](http://pypi.python.org/pypi/virtualenv) and [virtualenvwrapper](http://www.doughellmann.com/projects/virtualenvwrapper/). follow the instructions from those links for installing those.

then, from the directory this document is in do like this:

```
$ mkvirtualenv ecomom --no-site-packages
$ workon ecomom
$ pip install -r requirements.txt
```
you will be all set up.

to run just the benchmark tests, run:

```
$ nosetests selenium/benchmarks.py
```
