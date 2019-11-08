## --- BEGIN LICENSE BLOCK ---
# Copyright (c) 2016-present WeWantToKnow AS
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
## --- END LICENSE BLOCK ---

module U3d
  class UnityModule
    # Basic module attributes
    attr_reader :id, :name, :description, :url
    # Validation attributes
    attr_reader :installed_size, :download_size, :checksum

    def initialize(
      id:, name:, description:, url:,
      installed_size:, download_size:, checksum:)
      @id = id
      @name = name
      @description = description
      @url = url
      @installed_size = installed_size
      @download_size = download_size
      @checksum = checksum
    end

    def download_size_bytes(os)
      size_in_bytes(download_size)
    end

    def installed_size_bytes(os)
      size_in_bytes(installed_size)
    end

    class << self
      def load_modules(version, cached_versions, os: U3dCore::Helper.operating_system, offline: false)
        if version.kind_of? Array
          UI.verbose "Loading modules for several versions: #{version}"
          load_versions_modules(version, cached_versions, os, offline)
        else
          UI.verbose "Loading modules for version #{version}"
          load_version_modules(version, cached_versions, os, offline)
        end
      end

      private

      # Optimized version of load_version_modules that only makes one HTTP call
      def load_versions_modules(versions, cached_versions, os, offline)
        ini_modules = versions
          .map { |version| [version, INIModulesParser.load_ini(version, cached_versions, os: os, offline: offline)] }
          .map do |version, ini_data|
            url_root = cached_versions[version]
            modules = ini_data.map {|k,v| module_from_ini_data(k,v,url_root) }
            [version, modules]
          end.to_h

        HubModulesParser.download_modules(os: os) unless offline
        hub_modules = versions
          .map { |version| [version, HubModulesParser.load_modules(version, os: os, offline: true) ]}
          .map do |version, json_data|
            modules = json_data.map { |data| module_from_json_data(data) }
            [version, modules]
          end.to_h

        return ini_modules.merge(hub_modules) do |version, ini_version_modules, json_version_modules|
          (ini_version_modules + json_version_modules).uniq { |mod| mod.id }
        end
      end

      def load_version_modules(version, cached_versions, os, offline)
        ini_data = INIModulesParser.load_ini(version, cached_versions, os: os, offline: offline)
        url_root = cached_versions[version]
        ini_modules = ini_data.map {|k,v| module_from_ini_data(k,v,url_root) }

        json_data = HubModulesParser.load_modules(version, os: os, offline: offline)
        json_modules = json_data.map { |data| module_from_json_data(data) }

        return (ini_modules + json_modules).uniq { |mod| mod.id }
      end

      def module_from_ini_data(module_key, entries, url_root)
        url = entries['url']
        unless /^http/  =~ url
          url = url_root + url
        end

        UnityModule.new(
          id: module_key.downcase,
          name: entries['title'],
          description: entries['description'],
          url: url,
          download_size: entries['size'],
          installed_size: entries['installedsize'],
          checksum: entries['md5'])
      end
      
      def module_from_json_data(entries)
        UnityModule.new(
          id: entries['id'],
          name: entries['name'],
          description: entries['description'],
          url: entries['downloadUrl'],
          download_size: entries['downloadSize'],
          installed_size: entries['installedSize'],
          checksum: entries['checksum'])
      end
    end

    private

    def size_in_bytes(size, os)
      os == :win ? size * 1024 : size
    end
  end
end
