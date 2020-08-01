# frozen_string_literal: true

require 'spec_helper'

describe 'Capybara::Apparition', 'compatibility with selenium' do
  include AppRunner
  around do |example|
    old_length = RSpec::Support::ObjectFormatter.default_instance.max_formatted_output_length
    RSpec::Support::ObjectFormatter.default_instance.max_formatted_output_length = 5000
    example.run
    RSpec::Support::ObjectFormatter.default_instance.max_formatted_output_length = old_length
  end

  it 'generates the same events as selenium when filling out forms', :selenium_compatibility do
    run_application_for_html(<<-HTML)
      <html><body>
        <form onsubmit="return false">
          <label for="one">One</label><input type="text" name="one" id="one" class="watch" />
          <label for="two">Two</label><input type="text" name="two" id="two" class="watch" />
          <label for="three">Three</label><input type="text" name="three" id="three" readonly="readonly" class="watch" />
          <label for="textarea">Textarea</label>
          <textarea name="textarea" id="textarea"></textarea>
          <select name="select" id="five" class="watch">
            <option>Nothing here</option>
            <option>some option</option>
          </select>
          <input type="submit" value="Submit" id="submit" class="watch" />
        </form>
        <script type="text/javascript">
          window.log = [];
          var recordEvent = function (event) {
            log.push(event.target.id + '.' + event.type);
          };
          var elements = document.getElementsByClassName("watch");
          var events = ["mousedown", "mouseup", "click", "keyup", "keydown",
                        "keypress", "focus", "blur", "input", "change"];
          for (var i = 0; i < elements.length; i++) {
            for (var j = 0; j < events.length; j++) {
              elements[i].addEventListener(events[j], recordEvent);
            }
          }
        </script>
      </body></html>
    HTML

    pending "Chrome doesn't match spec on this - Our select option may not either"
    compare_events_for_drivers(:apparition, :selenium_chrome_headless) do
      visit '/'
      fill_in 'One', with: 'some value'
      fill_in 'One', with: 'a new value'
      fill_in 'Two', with: 'other value'
      fill_in 'Three', with: 'readonly value'
      fill_in 'Textarea', with: 'last value'
      select 'some option', from: 'five'
      click_button 'Submit'
    end
  end

  it 'generates the same requests and responses as selenium', :selenium_compatibility do
    requests = []

    app = Class.new(ExampleApp) do
      before do
        requests << request.path_info unless request.path_info.include?('favicon.ico')
      end

      get '/' do
        <<-HTML
          <html>
            <head>
              <script src="/one.js"></script>
              <script src="/two.js"></script>
            </head>
            <body>Original</body>
          </html>
        HTML
      end

      get '/:script.js' do
        ''
      end

      get '/requests' do
        <<-HTML
          <html>
            <body>
              #{requests.sort.join("\n")}
            </body>
          </html>
        HTML
      end
    end

    run_application app

    compare_for_drivers(:apparition, :selenium_chrome_headless) do |session|
      responses = []
      session.visit '/'
      responses << record_response(session)
      session.visit '/'
      responses << record_response(session)
      session.visit '/requests'
      responses << record_response(session)
      requests.clear
      responses.join("\n\n")
    end
  end

  def compare_events_for_drivers(first, second, &block)
    compare_for_drivers(first, second) do |session|
      session.instance_eval(&block)
      session.evaluate_script('window.log')
    end
  end

  def compare_for_drivers(first, second, &block)
    expect(for_driver(first, &block)).to eq for_driver(second, &block)
  end

  def for_driver(name)
    session = Capybara::Session.new(name, AppRunner.app)
    yield session
  end

  def record_response(session)
    [
      session.current_url,
      normalize_body(session.body)
    ].join("\n")
  end

  def normalize_body(body)
    if !body.empty?
      Nokogiri::HTML.parse(body).at('//body').text.strip
    else
      '(empty)'
    end
  end
end
