import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/order_service.dart';
import '../services/firebase_auth_service.dart';
import '../models/order.dart';

class OrderTrackingPage extends StatefulWidget {
  const OrderTrackingPage({super.key});

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _tabIndex = 0; // 0 active, 1 past
  late Stream<List<OrderModel>> _ordersStream;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _controller.forward();
    final userId = FirebaseAuthService().currentUser?.uid;
    if (userId != null) {
      _ordersStream = OrderService.instance.streamUserOrders(userId);
    } else {
      // Handle not logged in case - maybe show empty or redirect
      _ordersStream = Stream.value([]);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openTrackLive(OrderModel o) {
    if (o.status == OrderStatus.outForDelivery) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrackLivePage(order: o)));
    }
  }

  String _getStatusDisplayText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.refunded:
        return 'Refunded';
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.grey;
      case OrderStatus.accepted:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.orange;
      case OrderStatus.outForDelivery:
        return Colors.green;
      case OrderStatus.completed:
        return Colors.green[700]!;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.refunded:
        return Colors.red[700]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        elevation: 6,
        title: const Text('Orders & Tracking'),
        centerTitle: true,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.shopping_cart)),
        ],
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedControl(
                      labels: const ['Active', 'Past'],
                      value: _tabIndex,
                      onChanged: (v) => setState(() => _tabIndex = v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _tabIndex == 0 ? _buildActive() : _buildPast(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActive() {
    return StreamBuilder<List<OrderModel>>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final orders = snapshot.data ?? [];
        final active = orders.where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled).toList();
        if (active.isEmpty) return Center(child: Text('No active orders', style: Theme.of(context).textTheme.titleLarge));

        final o = active.first;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _OrderCard(order: o, onTrack: () => _openTrackLive(o)),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 8,
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Your Orders', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (ctx, i) {
                          final it = orders[i];
                          return _smallOrderCard(it);
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemCount: orders.length,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPast() {
    return StreamBuilder<List<OrderModel>>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final orders = snapshot.data ?? [];
        final past = orders.where((o) => o.status == OrderStatus.completed).toList();
        if (past.isEmpty) return Center(child: Text('No past orders', style: Theme.of(context).textTheme.titleLarge));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: past.length,
          itemBuilder: (ctx, i) => _smallOrderCard(past[i]),
        );
      },
    );
  }

  Widget _smallOrderCard(OrderModel o) {
    String statusText = _getStatusDisplayText(o.status);
    return GestureDetector(
      onTap: () => _openTrackLive(o),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(height: 48, width: 48, decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(10)), child: const Center(child: Text('🍕', style: TextStyle(fontSize: 22)))),
            const SizedBox(width: 8),
            Expanded(child: Text(o.id, style: const TextStyle(fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 8),
          Text(o.items.isNotEmpty ? o.items.first.name : 'Order', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(statusText, style: TextStyle(color: _getStatusColor(o.status), fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('₱${o.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900)), if (o.status == OrderStatus.outForDelivery) ElevatedButton(onPressed: () => _openTrackLive(o), child: const Text('Track')) else Container()])
        ]),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTrack;

  const _OrderCard({required this.order, required this.onTrack});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(height: 52, width: 52, decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('🍕', style: TextStyle(fontSize: 28)))),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Order ${order.id}', style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')} • ₱${order.total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.black54)),
              ])
            ]),
            IconButton(onPressed: () {}, icon: const Icon(Icons.expand_more))
          ]),
          const SizedBox(height: 12),
          _OrderProgress(status: order.status),
          const SizedBox(height: 12),
          Container(
            height: 140,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.grey[100], boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 6))]),
            child: Stack(alignment: Alignment.center, children: [
              Positioned(left: 14, top: 14, child: Container(width: 120, height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 6))]), child: const Center(child: Icon(Icons.map, size: 28, color: Colors.orange)))),
              Positioned(bottom: 12, child: ElevatedButton(onPressed: onTrack, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12), child: Text('Track Live'))))
            ]),
          )
        ]),
      ),
    );
  }
}

class _OrderProgress extends StatelessWidget {
  final OrderStatus status;

  const _OrderProgress({required this.status});

  int _indexFor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.accepted:
        return 1;
      case OrderStatus.preparing:
        return 2;
      case OrderStatus.outForDelivery:
        return 3;
      case OrderStatus.completed:
        return 4;
      case OrderStatus.cancelled:
        return 4; // Same as completed for UI
      case OrderStatus.refunded:
        return 4; // Same as completed for UI
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _indexFor(status);
    final steps = ['Order Placed', 'Accepted', 'Preparing', 'Out for Delivery', 'Delivered'];
    return Row(children: List.generate(5, (i) {
      final done = i <= active;
      final isCurrent = i == active && status != OrderStatus.completed && status != OrderStatus.cancelled && status != OrderStatus.refunded;
      return Expanded(
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: done ? Colors.deepOrange : (isCurrent ? Colors.orange[200] : Colors.white), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]), child: Icon(_getIconForStep(i), color: done ? Colors.white : (isCurrent ? Colors.orange : Colors.deepOrange), size: 18)),
          ]),
          const SizedBox(height: 8),
          Text(steps[i], textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: done ? FontWeight.w800 : FontWeight.w600, color: done ? Colors.black : Colors.black45)),
        ]),
      );
    }));
  }

  IconData _getIconForStep(int i) {
    switch (i) {
      case 0:
        return Icons.shopping_cart;
      case 1:
        return Icons.check_circle;
      case 2:
        return Icons.kitchen;
      case 3:
        return Icons.delivery_dining;
      case 4:
        return Icons.check_circle_outline;
      default:
        return Icons.circle;
    }
  }
}

class TrackLivePage extends StatefulWidget {
  final OrderModel order;

  const TrackLivePage({required this.order, super.key});

  @override
  State<TrackLivePage> createState() => _TrackLivePageState();
}

class _TrackLivePageState extends State<TrackLivePage> {
  final Completer<GoogleMapController> _mapController = Completer();
  Timer? _timer;
  int _posIndex = 0;

  // A short sample route (Manila-ish lat/lng). Replace or generate real coords in production.
  final List<LatLng> _route = [
    const LatLng(14.5995, 120.9842),
    const LatLng(14.6000, 120.9850),
    const LatLng(14.6006, 120.9862),
    const LatLng(14.6012, 120.9870),
    const LatLng(14.6018, 120.9878),
  ];

  late Marker _driverMarker;

  @override
  void initState() {
    super.initState();
    _driverMarker = Marker(
      markerId: const MarkerId('driver'),
      position: _route.first,
      infoWindow: InfoWindow(title: 'Driver', snippet: widget.order.id),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
    );

    // Start a simple timer to step the driver along the route.
    _timer = Timer.periodic(const Duration(seconds: 2), (t) async {
      if (!mounted) return;
      setState(() {
        _posIndex = (_posIndex + 1) % _route.length;
        _driverMarker = _driverMarker.copyWith(positionParam: _route[_posIndex]);
      });

      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLng(_route[_posIndex]));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deliveryLocation = widget.order.deliveryInfo.coordinates;
    final start = deliveryLocation != null ? LatLng(deliveryLocation.latitude, deliveryLocation.longitude) : _route.first;
    final eta = widget.order.eta;
    final etaText = eta != null ? '${eta.difference(DateTime.now()).inMinutes} mins' : 'Calculating...';

    return Scaffold(
      appBar: AppBar(title: Text('Tracking ${widget.order.id}')),
      body: Column(children: [
        Expanded(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: start, zoom: 15),
            onMapCreated: (controller) => _mapController.complete(controller),
            markers: {_driverMarker},
            polylines: deliveryLocation != null ? {
              Polyline(
                polylineId: const PolylineId('route'),
                points: [_route.first, start],
                color: Colors.deepOrange.withOpacity(0.9),
                width: 5,
              )
            } : {
              Polyline(
                polylineId: const PolylineId('route'),
                points: _route,
                color: Colors.deepOrange.withOpacity(0.9),
                width: 5,
              )
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Driver is on the way', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text('Estimated arrival: $etaText', style: const TextStyle(color: Colors.black54)),
              ]),
            ),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(), style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12), child: Text('Close')))
          ]),
        )
      ]),
    );
  }
}

class SegmentedControl extends StatelessWidget {
  final List<String> labels;
  final int value;
  final ValueChanged<int> onChanged;

  const SegmentedControl({required this.labels, required this.value, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))]),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: active ? Theme.of(context).colorScheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text(labels[i], style: TextStyle(color: active ? Colors.white : Colors.black87, fontWeight: FontWeight.w800))),
              ),
            ),
          );
        }),
      ),
    );
  }
}
