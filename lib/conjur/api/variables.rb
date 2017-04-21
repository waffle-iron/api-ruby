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
require 'conjur/variable'

module Conjur
  class API
  
    #@!group Directory: Variables

    # Fetch the values of a list of variables.  This operation is more efficient than fetching the
    # values one by one.
    #
    # This method will fail unless:
    #   * All of the variables exist
    #   * You have permission to `'execute'` all of the variables
    #
    # @example Fetch multiple variable values
    #   values = variable_values ['postgres_uri', 'aws_secret_access_key', 'aws_access_key_id']
    #   values # =>
    #   {
    #      "postgres_uri" => "postgres://..."
    #      "aws_secret_access_key" => "..."
    #      "aws_access_key_id" => "..."
    #   }
    #    #
    # This method is used to implement the {http://developer.conjur.net/reference/tools/utilities/conjurenv `conjur env`}
    # commands.  You may consider using that instead to run your program in an environment with the necessary secrets.
    #
    # @param [Array<String>] varlist list of variable ids to fetch
    # @return [Hash] a hash mapping variable ids to variable values
    # @raise [RestClient::Forbidden, RestClient::ResourceNotFound] if any of the variables don't exist or aren't accessible.
    def variable_values(varlist)
      raise ArgumentError, "Variables list must be an array" unless varlist.kind_of? Array
      raise ArgumentError, "Variables list is empty" if varlist.empty?
      opts = "?vars=#{varlist.map { |v| fully_escape(v) }.join(',')}"
      begin
        resp = RestClient::Resource.new(Conjur.configuration.core_url, self.credentials)['variables/values'+opts].get
        return JSON.parse( resp.body )
      rescue RestClient::ResourceNotFound
        return Hash[ *varlist.map { |v| [ v, variable(v).value ]  }.flatten ]
      end
    end
    
    #@!endgroup
  end
end
