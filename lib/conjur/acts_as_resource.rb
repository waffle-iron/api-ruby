#
# Copyright (C) 2013 Conjur Inc
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

module Conjur
  # This module is included in object classes that have resource behavior.
  module ActsAsResource
    include HasAttributes

    # The full role id of the role that owns this resource.
    #
    # @example
    #   api.current_role # => 'conjur:user:jon'
    #   resource = api.create_resource 'conjur:example:resource-owner'
    #   resource.owner # => 'conjur:user:jon'
    #
    # @return [String] the full role id of this resource's owner.
    def ownerid
      attributes['owner']
    end

    # Check whether this asset exists by performing a HEAD request to its URL.
    #
    # This method will return false if the asset doesn't exist.
    #
    # @example
    #   does_not_exist = api.user 'does-not-exist' # This returns without error.
    #
    #   # this is wrong!
    #   owner = does_not_exist.ownerid # raises RestClient::ResourceNotFound
    #
    #   # this is right!
    #   owner = if does_not_exist.exists?
    #     does_not_exist.ownerid
    #   else
    #     nil # or some sensible default
    #   end
    #
    # @return [Boolean] does it exist?
    def exists?
      begin
        rbac_resource_resource.head
        true
      rescue RestClient::Forbidden
        true
      rescue RestClient::ResourceNotFound
        false
      end
    end

    # Lists roles that have a specified privilege on the resource. 
    #
    # This will return only roles of which api.current_user is a member.
    #
    # Options:
    #
    # * **offset** Zero-based offset into the result set.
    # * **limit**  Total number of records returned.
    #
    # @example
    #   resource = api.resource 'conjur:variable:example'
    #   resource.permitted_roles 'execute' # => ['conjur:user:admin']
    #   resource.permit 'execute', api.user('jon')
    #   resource.permitted_roles 'execute' # => ['conjur:user:admin', 'conjur:user:jon']
    #
    # @param privilege [String] the privilege
    # @param options [Hash, nil] extra parameters to pass to the webservice method.
    # @return [Array<String>] the ids of roles that have `privilege` on this resource.
    def permitted_roles privilege, options = {}
      options[:permitted_roles] = true
      options[:privilege] = true
      result = JSON.parse rbac_resource_resource[options_querystring options].get
      if result.is_a?(Hash) && ( count = result['count'] )
        count
      else
        result
      end
    end

    # True if the logged-in role, or a role specified using the :acting_as option, has the
    # specified +privilege+ on this resource.
    #
    # @example
    #   api.current_role # => 'conjur:cat:mouse'
    #   resource.permitted_roles 'execute' # => ['conjur:user:admin', 'conjur:cat:mouse']
    #   resource.permitted_roles 'update', # => ['conjur:user:admin', 'conjur:cat:gino']
    #
    #   resource.permitted? 'update' # => false, `mouse` can't update this resource
    #   resource.permitted? 'execute' # => true, `mouse` can execute it.
    #   resource.permitted? 'update',acting_as: 'conjur:cat:gino' # => true, `gino` can update it.
    # @param privilege [String] the privilege to check
    # @param [Hash, nil] options for the request
    # @option options [String,nil] :acting_as check whether the role given by this full role id is permitted
    #   instead of checking +api.current_role+.
    # @return [Boolean]
    def permitted? privilege, options = {}
      options[:check] = true
      options[:privilege] = privilege
      rbac_resource_resource[options_querystring options].get
      true
    rescue RestClient::Forbidden
      false
    rescue RestClient::ResourceNotFound
      false
    end

    # Return an {Conjur::Annotations} object to manipulate and view annotations.
    #
    # @see Conjur::Annotations
    # @example
    #    resource.annotations.count # => 0
    #    resource.annotations['foo'] = 'bar'
    #    resource.annotations.each do |k,v|
    #       puts "#{k}=#{v}"
    #    end
    #    # output is
    #    # foo=bar
    #
    #
    # @return [Conjur::Annotations]
    def annotations
      @annotations ||= Conjur::Annotations.new(resource_resource)
    end
    alias tags annotations

    # @api private
    # This is documented by Conjur::API#resources.
    # Returns all resources (optionally qualified by kind) visible to the user with given credentials.
    #
    #
    # Options are:
    # - host - authz url,
    # - credentials,
    # - account,
    # - owner (optional),
    # - kind (optional),
    # - search (optional),
    # - limit (optional),
    # - offset (optional).
    def self.all options = {}
      host, credentials, account, kind = options.values_at(*[:host, :credentials, :account, :kind])
      fail ArgumentError, "host and account are required" unless [host, account].all?
      %w(host credentials account kind).each do |name|
        options.delete(name.to_sym)
      end

      credentials ||= {}

      path = "#{account}/resources" 
      path += "/#{kind}" if kind

      result = JSON.parse(core_resource[path][options_querystring options].get)

      result = result['count'] if result.is_a?(Hash)
      result
    end
    
    private
    
    # RestClient::Resource for RBAC resource operations.
    def rbac_resource_resource
      RestClient::Resource.new(Conjur.configuration.core_url, credentials)['resources'][id.to_url_path]
    end

    # RestClient::Resource for RBAC role operations.
    def rbac_role_resource
      RestClient::Resource.new(Conjur.configuration.core_url, credentials)['roles'][id.to_url_path]
    end
  end
end
