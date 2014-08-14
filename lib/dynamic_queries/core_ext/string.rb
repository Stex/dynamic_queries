class String
  def try_html_safe
    html_safe if respond_to?(:html_safe)
  end
end