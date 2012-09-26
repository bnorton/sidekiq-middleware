module Sidekiq
  module Middleware
    module Server
      class UniqueJobs

        def call(worker_instance, item, queue)
          forever = worker_instance.class.get_sidekiq_options['forever']

          # Delete lock first if forever is set
          # Used for jobs which may scheduling self in future
          clear(worker_instance, item, queue) if forever

          begin
            yield
          ensure
            clear(worker_instance, item, queue) unless forever
          end
        end

        def clear(worker_instance, item, queue)
          enabled, payload = worker_instance.class.get_sidekiq_options['unique'], item.clone

          payload.delete('jid')
          payload.delete('sent_at')

          # Enabled unique scheduled 
          if enabled == :all && item.has_key?('at')
            payload.delete('at')
          end

          payload_hash = Digest::MD5.hexdigest(Sidekiq.dump_json(Hash[payload.sort]))
          
          Sidekiq.redis { |conn| conn.del(payload_hash) }
        end

      end
    end
  end
end
