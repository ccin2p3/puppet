require 'puppet/util/inifile'

Puppet::Type.type(:yumrepo).provide(:inifile) do
  desc 'Manage yum repos'

  def self.instances
    instances = []
    # Iterate over each section of our virtual file.
    virtual_inifile.each_section do |s|
      attributes_hash = {:name => s.name, :ensure => :present, :provider => :yumrepo}
      # We need to build up a attributes hash
      s.instance_variable_get('@entries').each do |k, v|
        key = k.to_sym
        if valid_property(key)
          # We strip the values here to handle cases where distros set values
          # like enabled = 1 with spaces.
          attributes_hash[key] = v.strip
        end
      end
      instances << new(attributes_hash)
    end
  return instances
  end

  def self.prefetch(resources)
    repos = instances
    resources.keys.each do |name|
      if provider = repos.find { |repo| repo.name == name }
        resources[name].provider = provider
      end
    end
  end

  # Search for a reposdir in yum's configuration file
  #  and return it if it's an existing directory.
  def self.reposdir(conf='/etc/yum.conf')
    dir = ['/etc/yum.repos.d', '/etc/yum/repos.d']
    contents = File.read(conf) if File.exists?(conf)
    if match = contents.match(/^reposdir\s*=\s*(.*)/)
      dir << match.captures
    end

    return dir
  end

  # Build a virtual inifile by reading in numerous .repo
  # files into a single virtual file to ease manipulation.
  def self.virtual_inifile
    if @virtual.nil?
      @virtual = Puppet::Util::IniConfig::File.new
      reposdir.each do |dir|
        Dir::glob("#{dir}/*.repo").each do |file|
          @virtual.read(file) if ::File.file?(file)
        end
      end
    end
    return @virtual
  end

  def self.valid_property(key)
    return true if Puppet::Type.type(:yumrepo).validproperties.include?(key)
  end

  # Return the named section out of the virtual_inifile.
  def self.section(name)
    result = self.virtual_inifile[name]
    # Create a new section if not found.
    if result.nil?
      reposdir.each do |dir|
        if File.directory?(dir)
          path = ::File.join(dir, "#{name}.repo")
          Puppet::info("create new repo #{name} in file #{path}")
          result = self.virtual_inifile.add_section(name, path)
        end
      end
    end
    result
  end

  # Store all modifications back to disk
  def self.store
    inifile = self.virtual_inifile
    inifile.store
    unless Puppet[:noop]
      target_mode = 0644 # FIXME: should be configurable
      inifile.each_file do |file|
        current_mode = Puppet::FileSystem::File.new(file).stat.mode & 0777
        unless current_mode == target_mode
          Puppet::info "changing mode of #{file} from %03o to %03o" % [current_mode, target_mode]
          ::File.chmod(target_mode, file)
        end
      end
    end
  end

  def create
    @property_hash[:ensure] = :present

    # We fetch a list of properties from the type, then iterate
    # over them, avoiding ensure.  We're relying on .should to
    # check if the property has been set and should be modified,
    # and if so we set it in the virtual inifile.
    Puppet::Type.type(:yumrepo).validproperties.each do |property|
      unless property == :ensure
        if value = @resource.should(property)
          section(@resource[:name]).[]=(property.to_s, value)
          @property_hash[property] = value
        end
      end
    end

    exists? ? (return true) : (return false)
  end

  def destroy
    # Flag file for deletion on flush.
    section(@property_hash[:name]).destroy=(true)

    @property_hash.clear
    exists? ? (return false) : (return true)
  end

  def flush
    # Ensure we only call the class store once no matter how much flushing is required.
    self.class.store
  end

  def section(name)
    self.class.section(name)
  end

  # Create all of our setters.
  mk_resource_methods
  Puppet::Type.type(:yumrepo).validproperties.each do |property|
    # Exclude ensure, as we don't need to create an ensure=
    unless property == :ensure
      # Builds the property= method.
      define_method("#{property.to_s}=") do |value|
        section(@property_hash[:name]).[]=(property.to_s, value)
        @property_hash[property] = value
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present || false
  end

end
