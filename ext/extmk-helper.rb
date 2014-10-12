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

  def extract_makefile(makefile, keep = true)
    m = File.read(makefile)
    if !(target = m[/^TARGET[ \t]*=[ \t]*(\S*)/, 1])
      return keep
    end
    installrb = {}
    m.scan(/^install-rb-default:.*[ \t](\S+)(?:[ \t].*)?\n\1:[ \t]*(\S+)/) {installrb[$2] = $1}
    oldrb = installrb.keys.sort
    newrb = install_rb(nil, "").collect {|d, *f| f}.flatten.sort
    unless oldrb == newrb
      if $extout
        newrb.each {|f| installrb.delete(f)}
        unless installrb.empty?
          config = CONFIG.dup
          install_dirs(target_prefix).each {|var, val| config[var] = val}
          FileUtils.rm_f(installrb.values.collect {|f| RbConfig.expand(f, config)},
                         :verbose => verbose?)
        end
      end
      return false
    end
    srcs = Dir[File.join($srcdir, "*.{#{SRC_EXT.join(%q{,})}}")].map {|fn| File.basename(fn)}.sort
    if !srcs.empty?
      old_srcs = m[/^ORIG_SRCS[ \t]*=[ \t](.*)/, 1] or return false
      old_srcs.split.sort == srcs or return false
    end
    $target = target
    $extconf_h = m[/^RUBY_EXTCONF_H[ \t]*=[ \t]*(\S+)/, 1]
    if $static.nil?
      $static ||= m[/^EXTSTATIC[ \t]*=[ \t]*(\S+)/, 1] || false
      /^STATIC_LIB[ \t]*=[ \t]*\S+/ =~ m or $static = false
    end
    $preload = Shellwords.shellwords(m[/^preload[ \t]*=[ \t]*(.*)/, 1] || "")
    if dldflags = m[/^dldflags[ \t]*=[ \t]*(.*)/, 1] and !$DLDFLAGS.include?(dldflags)
      $DLDFLAGS += " " + dldflags
    end
    if s = m[/^LIBS[ \t]*=[ \t]*(.*)/, 1]
      s.sub!(/^#{Regexp.quote($LIBRUBYARG)} */, "")
      s.sub!(/ *#{Regexp.quote($LIBS)}$/, "")
        $libs = s
    end
    $objs = (m[/^OBJS[ \t]*=[ \t](.*)/, 1] || "").split
    $srcs = (m[/^SRCS[ \t]*=[ \t](.*)/, 1] || "").split
    $distcleanfiles = (m[/^DISTCLEANFILES[ \t]*=[ \t](.*)/, 1] || "").split
    $LOCAL_LIBS = m[/^LOCAL_LIBS[ \t]*=[ \t]*(.*)/, 1] || ""
    $LIBPATH = Shellwords.shellwords(m[/^libpath[ \t]*=[ \t]*(.*)/, 1] || "") - %w[$(libdir) $(topdir)]
    true
  end
end
