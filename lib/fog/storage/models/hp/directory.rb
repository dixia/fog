require 'fog/core/model'
require 'fog/storage/models/hp/files'

module Fog
  module HP
    class Storage

      class Directory < Fog::Model

        identity  :key, :aliases => 'name'

        attribute :bytes, :aliases => 'X-Container-Bytes-Used'
        attribute :count, :aliases => 'X-Container-Object-Count'

        def acl=(new_acl)
          valid_acls = ['private', 'public-read', 'public-write', 'public-read-write']
          unless valid_acls.include?(new_acl)
            raise ArgumentError.new("acl must be one of [#{valid_acls.join(', ')}]")
          end
          @acl = new_acl
        end

        def destroy
          requires :key
          connection.delete_container(key)
          # Added an extra check to see if CDN is nil i.e. when CDN provider is not implemented yet.
          if !connection.cdn.nil?
            connection.cdn.post_container(key, 'X-CDN-Enabled' => 'False')
          end
          true
        rescue Excon::Errors::NotFound
          false
        end

        def files
          @files ||= begin
            Fog::HP::Storage::Files.new(
              :directory    => self,
              :connection   => connection
            )
          end
        end

        def public=(new_public)
          if new_public
            @acl = 'public-read'
          else
            @acl = 'private'
          end
          @public = new_public
        end

        def public_url
          requires :key
          @public_url ||= begin
            if !connection.cdn.nil?
              begin response = connection.cdn.head_container(key)
                if response.headers['X-CDN-Enabled'] == 'True'
                  if connection.hp_cdn_ssl == true
                    response.headers['X-CDN-SSL-URI']
                  else
                    response.headers['X-CDN-URI']
                  end
                end
              rescue Fog::Service::NotFound
                nil
              end
            else
              begin response = connection.head_container(key)
                url = "#{connection.url}/#{key}"
              rescue Fog::Service::NotFound
                nil
              end
            end
          end
        end

        def save
          requires :key
          options = {}
          if @acl
            options.merge!(connection.acl_to_header(@acl))
          end
          connection.put_container(key, options)
          # Added an extra check to see if CDN is nil i.e. when CDN provider is not implemented yet.
          if !connection.cdn.nil?
            if @public
              @public_url = connection.cdn.put_container(key, 'X-CDN-Enabled' => 'True').headers['X-CDN-URI']
            else
              connection.cdn.put_container(key, 'X-CDN-Enabled' => 'False')
              @public_url = nil
            end
          end
          true
        end

      end

    end
  end
end
