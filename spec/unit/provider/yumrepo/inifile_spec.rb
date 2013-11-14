require 'spec_helper'
require 'puppet'

describe Puppet::Type.type(:yumrepo).provider(:inifile) do
  let(:yumrepo) {
    Puppet::Type.type(:yumrepo).new(
      :name     => 'puppetlabs-products',
      :ensure   => :present,
      :baseurl  => 'http://yum.puppetlabs.com/el/6/products/$basearch',
      :descr    => 'Puppet Labs Products El 6 - $basearch',
      :enabled  => '1',
      :gpgcheck => '1',
      :gpgkey   => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-puppetlabs'
    )
  }
  let(:yumrepo_provider) { yumrepo.provider }
  let(:repo_file) { '
[updates]
name="updates"
enabled = 1
descr="test updates"
'
  }

  before :each do
    yumrepo_provider.class.stubs(:reposdir).returns(['/etc/yum.repos.d'])
    Dir.stubs(:glob).with('/etc/yum.repos.d/*.repo').returns(['/etc/yum.repos.d/test.repo'])
  end

  describe 'self.instances' do
    before :each do
      File.expects(:file?).with('/etc/yum.repos.d/test.repo').returns(true)
      File.expects(:exist?).with(Pathname.new('/etc/yum.repos.d/test.repo')).returns(true)
      File.expects(:read).with('/etc/yum.repos.d/test.repo').returns(repo_file)
    end

    it do
      providers = yumrepo_provider.class.instances
      providers.count.should == 1
      providers[0].name.should == 'updates'
      providers[0].enabled.should == '1'
    end
  end

  describe 'self.prefetch' do
    it 'exists' do
      yumrepo_provider.class.instances
      yumrepo_provider.class.prefetch({})
    end
  end

  describe 'create' do
    it 'creates a yumrepo' do
      File.stubs(:directory?).with('/etc/yum.repos.d').returns(true)
      yumrepo_provider.create.should be_true
    end
  end

  describe 'destroy' do
    it 'destroys a repo' do
      File.stubs(:directory?).with('/etc/yum.repos.d').returns(true)
      yumrepo_provider.destroy.should be_true
    end
  end

  describe 'exists?' do
    it 'checks if yumrepo exists' do
      yumrepo_provider.ensure= :present
      yumrepo_provider.exists?.should be_true
   end
  end

end
