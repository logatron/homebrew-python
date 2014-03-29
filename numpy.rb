require 'formula'

class NoUserConfig < Requirement
  def satisfied?
    not File.exist? "#{ENV['HOME']}/.numpy-site.cfg"
  end

  def message; <<-EOS.undent
      A ~/.numpy-site.cfg has been detected, which may interfere with our business.
    EOS
  end
end

class Numpy < Formula
  homepage 'http://www.numpy.org'
  url 'https://downloads.sourceforge.net/project/numpy/NumPy/1.8.1/numpy-1.8.1.tar.gz'
  sha1 '8fe1d5f36bab3f1669520b4c7d8ab59a21a984da'
  head 'https://github.com/numpy/numpy.git'

  depends_on :python => :recommended
  depends_on :python3 => :optional
  depends_on 'nose' => :python
  depends_on :python3 => 'nose' if build.with? 'python3'
  depends_on :fortran
  depends_on NoUserConfig
  depends_on 'homebrew/science/suite-sparse'  # for libamd and libumfpack

  option 'with-openblas', "Use openBLAS (slower for LAPACK functions) instead of Apple's Accelerate Framework"
  depends_on "homebrew/science/openblas" => :optional

  def install
    # Numpy is configured via a site.cfg and we want to use some libs
    # For maintainers:
    # Check which BLAS/LAPACK numpy actually uses via:
    # xcrun otool -L /usr/local/Cellar/numpy/1.6.2/lib/python2.7/site-packages/numpy/linalg/lapack_lite.so
    config = <<-EOS.undent
      [DEFAULT]
      library_dirs = #{HOMEBREW_PREFIX}/lib
      include_dirs = #{HOMEBREW_PREFIX}/include

      [amd]
      amd_libs = amd, cholmod, colamd, ccolamd, camd, suitesparseconfig
      [umfpack]
      umfpack_libs = umfpack

    EOS

    if build.with? 'openblas'
      openblas_dir = Formula["openblas"].opt_prefix
      # Setting ATLAS to None is important to prevent numpy from always
      # linking against Accelerate.framework.
      ENV['ATLAS'] = "None"
      ENV['BLAS'] = ENV['LAPACK'] = "#{openblas_dir}/lib/libopenblas.dylib"

      config << <<-EOS.undent
        [openblas]
        libraries = openblas
        library_dirs = #{openblas_dir}/lib
        include_dirs = #{openblas_dir}/include
      EOS
    end

    rm_f 'site.cfg' if build.devel?
    Pathname('site.cfg').write config

    # Numpy ignores FC and FCFLAGS, but we declare fortran so Homebrew knows
    # gfortran is gnu95
    system "python", "setup.py", "build", "--fcompiler=gnu95", "install", "--prefix=#{prefix}"
  end

  def test
    system "python", "-c", "import numpy; numpy.test()"
  end

  def caveats
    s = "Numpy ignores the `FC` env var and looks for gfortran during build.\n"
  end
end
