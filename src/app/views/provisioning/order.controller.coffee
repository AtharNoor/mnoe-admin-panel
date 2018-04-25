@App.controller('ProvisioningOrderCtrl', ($scope, $q, $state, $stateParams, MnoeOrganizations, MnoeProvisioning, MnoeAdminConfig, ProvisioningHelper) ->
  vm = this
  vm.product = null
  vm.subscription = MnoeProvisioning.getSubscription()
  if _.isEmpty(vm.subscription)
    vm.isLoading = true
    orgPromise = MnoeOrganizations.get($stateParams.orgId)
    initPromise = MnoeProvisioning.initSubscription({productId: $stateParams.productId, subscriptionId: $stateParams.subscriptionId, orgId: $stateParams.orgId})

    vm.pricedPlan = ProvisioningHelper.pricedPlan

    $q.all({organization: orgPromise, subscription: initPromise}).then(
      (response) ->
        vm.orgCurrency = response.organization.data.billing_currency || MnoeAdminConfig.marketplaceCurrency()
        vm.subscription = response.subscription
        vm.subscription.organization_id = response.organization.data.id

        # When in edit mode, we will be getting the product ID from the subscription, otherwise from the url.
        productId = vm.subscription.product?.id || $stateParams.productId
        MnoeProvisioning.getProduct(productId, { editAction: $stateParams.editAction }).then(
          (response) ->
            vm.subscription.product = response
            return vm.next(vm.subscription) if vm.skipPriceSelection(vm.subscription.product)

            # Filters the pricing plans not containing current currency
            vm.subscription.product.product_pricings = _.filter(vm.subscription.product.product_pricings,
              (pp) -> !vm.pricedPlan(pp) || _.some(pp.prices, (p) -> p.currency == vm.orgCurrency)
            )

            MnoeProvisioning.setSubscription(vm.subscription)
        )
    ).finally(-> vm.isLoading = false)

  vm.subscriptionPlanText = () ->
    switch $stateParams.editAction
      when 'NEW'
        'mnoe_admin_panel.dashboard.provisioning.order.new_title'
      when 'CHANGE'
        'mnoe_admin_panel.dashboard.provisioning.order.change_title'

  vm.next = (subscription) ->
    MnoeProvisioning.setSubscription(subscription)
    params = {
      productId: $stateParams.productId,
      orgId: $stateParams.orgId,
      subscriptionId: $stateParams.subscriptionId,
      editAction: $stateParams.editAction
    }
    if vm.subscription.product.custom_schema?
      $state.go('dashboard.provisioning.additional_details', params)
    else
      $state.go('dashboard.provisioning.confirm', params)

  # Delete the cached subscription when we are leaving the subscription workflow.
  $scope.$on('$stateChangeStart', (event, toState) ->
    switch toState.name
      when "dashboard.provisioning.confirm", "dashboard.provisioning.order_summary", "dashboard.provisioning.additional_details"
        null
      else
        MnoeProvisioning.setSubscription({})
  )

  # Skip pricing selection for products with product_type 'application' if
  # single billing is disabled or if single billing is enabled but externally managed
  vm.skipPriceSelection = (product) ->
    product.product_type == 'application' && (!product.single_billing_enabled || !product.billed_locally)

  return
)
