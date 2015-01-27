#!/usr/bin/python

import sys
import wave as wv

def main(argv):
    if len(argv) != 2:
        sys.stderr.write('USAGE:\n')
        sys.stderr.write('    %s wavFileIn\n' % argv[0])

        return 1
    else:
        # e.g. "test.wav"
        wavFileIn = argv[1]

        waveReader = wv.open(wavFileIn, 'rb')
        try:
            print 'num channels = %s' % waveReader.getnchannels()
            print 'bit depth = %s' % (waveReader.getsampwidth() * 8)
            print 'sampling frequency = %s' % waveReader.getframerate()
            print 'compression = %s' % waveReader.getcomptype()
        finally:
            waveReader.close()

        return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv))
