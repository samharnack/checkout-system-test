defmodule CheckoutTest do
  use ExUnit.Case

  alias Checkout.Cart
  alias Checkout.Discount
  alias Checkout.Product

  doctest Checkout.Cart
  doctest Checkout.Discount

  setup do
    products =
      %{
        green_tea: %Product{
          id: "GR1",
          name: "Green Tea",
          price_in_cents: 311
        },
        strawberries: %Product{
          id: "SR1",
          name: "Strawberries",
          price_in_cents: 500
        },
        coffee: %Product{
          id: "CF1",
          name: "Coffee",
          price_in_cents: 1123
        }
      }

    discounts =
      [
        %Discount{
          name: "Buy One Get One Free",
          minimum_quantity: 1,
          discount: 0.5,
          discount_type: :percentage,
          products: [products.green_tea],
          bundle_size: 2
        },
        %Discount{
          name: "Bulk Discount Strawberries",
          minimum_quantity: 3,
          discount: 50,
          discount_type: :unit_price,
          products: [products.strawberries]
        },
        %Discount{
          name: "Bulk Discount Coffee",
          minimum_quantity: 3,
          discount: 0.3333,
          discount_type: :percentage,
          products: [products.coffee]
        }
      ]

    cart = Cart.new(discount_resolver: &discount_resolver(&1, discounts))

    %{products: products, cart: cart}
  end

  test "buy one get one free with odd number of items", %{products: products, cart: cart} do
    # Basket: GR1,SR1,GR1,GR1,CF1
    cart =
      cart
      |> Cart.add_product(products.green_tea)
      |> Cart.add_product(products.strawberries)
      |> Cart.add_product(products.green_tea)
      |> Cart.add_product(products.green_tea)
      |> Cart.add_product(products.coffee)

    # Total price expected: £22.45
    assert Cart.calculate_total(cart) == 2245
  end

  test "buy one get one free with even number of items", %{products: products, cart: cart} do
    # Basket: GR1,GR1
    cart = Cart.add_product(cart, products.green_tea, 2)

    # Total price expected: £3.11
    assert Cart.calculate_total(cart) == 311
  end

  test "price discount on bulk items", %{products: products, cart: cart} do
    # Basket: SR1,SR1,GR1,SR1
    cart =
      cart
      |> Cart.add_product(products.strawberries)
      |> Cart.add_product(products.strawberries)
      |> Cart.add_product(products.green_tea)
      |> Cart.add_product(products.strawberries)

    # Total price expected: £16.61
    assert Cart.calculate_total(cart) == 1661
  end

  test "percentage discount on bulk items", %{products: products, cart: cart} do
    # Basket: GR1,CF1,SR1,CF1,CF1
    cart =
      cart
      |> Cart.add_product(products.green_tea)
      |> Cart.add_product(products.coffee)
      |> Cart.add_product(products.strawberries)
      |> Cart.add_product(products.coffee)
      |> Cart.add_product(products.coffee)

    # Total price expected: £30.57
    assert Cart.calculate_total(cart) == 3057
  end

  @doc """
  Resolves applicable discounts for products in the cart. This resolver searches the
  list of discounts provided.

  In a real world environment this allows you to perform a single database query for
  discounts rather than a query per product.
  """
  def discount_resolver(products, discounts) do
    Map.new(products, fn {product, quantity} ->
      discounts =
        Enum.filter(discounts, fn
          %Discount{products: products, minimum_quantity: min_quantity} ->
            product in products and quantity >= min_quantity

          _ ->
            false
        end)

      {{product, quantity}, discounts}
    end)
  end
end
