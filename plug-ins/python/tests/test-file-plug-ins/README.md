GIMP-file-plugin-tests
======================

Version 0.4
Jacob Boerema, 2021-2023

Introduction
------------

This is a Python 3 plug-in for testing GIMP file import plug-ins for API
version 3. This plug-in can be run both from within GIMP and from the
commandline.
The intention is to test both file import and export but currently only
importing is implemented.


File import plug-ins
--------------------

At this moment the following file import plug-ins have
tests available:
- file-bmp
- file-dds
- file-gif
- file-jpeg
- file-png
- file-pnm
- file-psb
- file-psd
- file-psd-load-merged
- file-sgi
- file-tga
- file-tiff

Requirements/Installation
------------

1. For running as a plug-in in GIMP add this plug-in to a location
   that GIMP knows of for plug-ins. This is not necessary for using
   the batch version of the plug-in.
2. There is a `tests` folder inside the plug-in folder for
   configuration files. The main configuration file is
   `config.ini`. This is where you define the file loading
   plug-ins to test. Each plug-in has its own configuration
   file that define the tests which should be in the same
   folder.
   The location and name of this file can be changed by setting an
   environment variable: GIMP_TESTS_CONFIG_FILE.
3. The plug-in specific configuration file, e.g.
   `png-tests.ini` defines the specific test sets.
   Each test set can be enabled/disabled and needs to
   have a folder set where the test images can be found.
   This folder should be relative to the base test data folder.
   By default this is the ./data/ folder, but it can also be
   changed, see below.
   The specific test images are defined in a file
   set in `files=`.
   These files are expected to be in the same folder as
   your config.ini.
   The root folder for all test images is by default ./data/.
   This folder can be changed by setting the environment variable
   GIMP_TESTS_DATA_FOLDER.
4. The file that defines the images to be tested should be a text file
   where each line contains the filename of a test image
   followed by a ',' and then what the expected
   result of loading is. For an example see
   `psd-tests.files`. Currently there are four results
   defined:
   - EXPECTED_OK (the default if omitted, if loading should succeed)
   - EXPECTED_FAIL (if loading should fail)
   - EXPECTED_TODO (if loading is currently expected to
     fail but the intention is to fix this in the future)
   - SKIP (this temporarily skips testing a file, useful when a file causes
     problems working on other test files)

How to run
----------

Start GIMP, then start the plug-in from:
- Menu Filters, Development, Python-Fu, Run import tests.

Or, from the commandline or a shell script:
- export GIMP_TESTS_CONFIG_FILE="/location/of/config.ini"
- export GIMP_TESTS_LOG_FILE="/location/of/logfile.log"
- export GIMP_TESTS_DATA_FOLDER="/location/of/test-images/rootfolder/"
- export PYTHONPATH="/location/of/your/python/script/"
- cd location/of/plug-in/gimp-file-plugin-tests
- cat gimpbatchtests.py | gimp-console-2.99 -idf --batch-interpreter python-fu-eval -b - --quit

In case you run the batch version, the log file is written to the folder
where the plug-in resides. This location can be adjusted by setting the
environment variable GIMP_TESTS_LOG_FILE.

Note
----

The only thing currently being tested is whether the image
loads or not. No testing is done to see if the image is
correctly shown.

Status
------
- When running all tiff tests from inside GIMP, it may crash, at least on
  Windows, due to the error console running out of resources because of
  the amount of messages.
- There is some preliminary export testing support, see gimpbatchexporttests.py.

  Future enhancements
  -------------------
- To test for success or regressions in batch mode you can test whether there
  were regressions.
  You should grep for `Total number of regressions: 0`.
- Add tests for all our image loading plug-ins
- Test if loaded images are loaded correctly, i.e.
  do they look like they should
- Fuzzing of images before loading to test our
  handling of corrupt images
- Automated downloading of pre selected test images
- GUI to select/deselect tests
- Test file export
- It would be nice to be able to capture all stdout/stderr output and
  possibly filter it for crashes, criticals and warnings.
