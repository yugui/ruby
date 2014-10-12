module ExtmkHelper
  DUMMY_SIGNATURE = "***DUMMY MAKEFILE***"

  def null
    @@null ||= if defined?(File::NULL)
                 @null = File::NULL
               elsif !File.chardev?(@null = "/dev/null")
                 @null = "nul"
               end
  end

  def sysquote(x)
    @quote ||= /os2/ =~ (CROSS_COMPILING || RUBY_PLATFORM)
    @quote ? x.quote : x
  end

  def verbose?
    $mflags.defined?("V") == "1"
  end

  def system(*args)
    if verbose?
      if args.size == 1
        puts args
      else
        puts Shellwords.join(args)
      end
    end
    super
  end

  def atomic_write_open(filename)
    filename_new = filename + ".new.#$$"
    open(filename_new, "wb") do |f|
      yield f
    end
    if File.binread(filename_new) != (File.binread(filename) rescue nil)
      File.rename(filename_new, filename)
    else
      File.unlink(filename_new)
    end
  end
end
