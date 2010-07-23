require 'digest/md5'

# Simple class to track events and report
# events per second or per defined time
# period.
#
# This is probably not the best way to do
# this but I needed something quickly on
# short notice and came up with this
class RateLimit
    attr_reader :timespan

    # timespan - how many seconds you want to track events for.
    #            events older than this will drop off the queue
    def initialize(timespan)
        @timespan = timespan
        @events = []
    end

    # Record that an event happened
    #
    # Just pass in any text, unique textx
    # will be tracked individually
    def record(event)
        key = Digest::MD5.hexdigest(event)

        event = {:k => key,
                 :t => Time.now.to_f}

        @events << event

        domaint
    end

    # Attempts to calculate a per second
    # figure for events, succeptable to
    # skewing early on but tends to be
    # correct after a number of events
    def rate_per_second(event)
        key = Digest::MD5.hexdigest(event)

        oldest = Time.now.to_f
        newest = 0
        events = 0

        @events.each do |e|
            if e[:k] == key
                events += 1

                oldest = e[:t] if e[:t] < oldest
                newest = e[:t]
            end
        end

        if (newest - oldest) > 1
            return events / (newest - oldest)
        else
            return 0
        end
    end

    # How many times have the event been seen
    # in the last interval
    def rate(event)
        key = Digest::MD5.hexdigest(event)

        @events.select{|e| e[:k] == key}.size
    end

    private
    # Deletes events older than the defined timespan
    def domaint
        @events.each_with_index do |event, idx|
            # events are stored in time order
            # delete them till we find ont thats
            # newer then we can stop looking
            if event[:t].to_f < (Time.now.to_f - @timespan.to_f)
                @events.delete_at(idx)
            else
                return
            end
        end
    end
end
