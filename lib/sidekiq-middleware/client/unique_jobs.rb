module Sidekiq
  module Middleware
    module Client
      class UniqueJobs
        HASH_KEY_EXPIRATION = 30 * 60

        def call(worker_class, item, queue)
          enabled = worker_class.get_sidekiq_options['unique']

          if enabled
            unique, payload = false, item.clone

            payload.delete('jid')
            payload.delete('sent_at')

            # Enabled unique scheduled
            if enabled == :all && item.has_key?('at')
              expiration = worker_class.get_sidekiq_options['expiration'] || (item['at'].to_i - Time.new.to_i)
              payload.delete('at')
            else
              expiration = worker_class.get_sidekiq_options['expiration'] || HASH_KEY_EXPIRATION
            end

            payload_hash = "unique:jobs:" + Digest::MD5.hexdigest(Sidekiq.dump_json(Hash[payload.sort]))

            Sidekiq.redis do |conn|
              conn.watch(payload_hash)

              if conn.get(payload_hash)
                conn.unwatch
              else
                unique = conn.multi do
                  conn.setex(payload_hash, expiration, 1)
                end
              end
            end

            yield if unique
          else
            yield
          end
        end

      end
    end
  end
end
