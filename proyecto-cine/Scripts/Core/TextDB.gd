extends Node

var locale: String = "es"

func set_locale(lang: String) -> void:
	locale = lang

func t(key: String) -> String:
	var table := _dict_for_locale(locale)
	if table.has(key):
		return String(table[key])

	var es := _dict_for_locale("es")
	if es.has(key):
		return String(es[key])

	return "[" + key + "]"

func tf(key: String, vars: Dictionary) -> String:
	var s := t(key)
	for k in vars.keys():
		s = s.replace("{" + String(k) + "}", String(vars[k]))
	return s

func _dict_for_locale(lang: String) -> Dictionary:
	match lang:
		"en": return _EN
		_:    return _ES

var _ES: Dictionary = {
	"ui.counter_ready": "[E] atender al cliente",

	"cust.greet.1": "Hola… ¿me echas una mano con la cartelera?",
	"cust.greet.2": "Buenas. Vengo a desconectar un rato.",
	"cust.greet.3": "Ey. Hoy necesito una peli que me saque de la cabeza el día.",
	"cust.greet.4": "Hola. Me apetece algo concreto, pero no sé cómo pedirlo bien.",

	"cust.foodask.1": "Ah, y también querré algo para picar.",
	"cust.foodask.2": "Y de paso… dame algo de comida, que vengo con hambre.",
	"cust.foodask.3": "Antes de entrar: algo de snack, por favor.",

	"cust.react_ok.1": "Vale… tiene buena pinta. Me fío.",
	"cust.react_ok.2": "Perfecto. Era justo el tipo de noche que buscaba.",
	"cust.react_ok.3": "Bien. Suena a que me va a encajar.",
	"cust.react_ok.4": "Genial, esa me cuadra.",

	"cust.react_bad.1": "Mmm… no sé… pero bueno, por probar.",
	"cust.react_bad.2": "No era lo que imaginaba… pero ya que estoy aquí.",
	"cust.react_bad.3": "Uff… me la estoy jugando, ¿eh?",
	"cust.react_bad.4": "Vale… confío, pero como sea un tostón te lo diré.",

	"cust.goodbye.1": "Perfecto. Gracias. ¡Nos vemos!",
	"cust.goodbye.2": "Gracias. Si me gusta, vuelvo.",
	"cust.goodbye.3": "Gracias. Que tengas buena noche.",
	"cust.goodbye.4": "¡Hecho! Gracias.",

	# ====== MOVIES (20) ======
	"movie.alien.title": "El octavo pasajero",
	"movie.alien.syn": "Una nave de carga responde a una señal desconocida y la tripulación investiga.\nTras un contacto “accidental”, algo se cuela a bordo.\nEn el vacío del espacio, sobrevivir es cuestión de nervios.\nY nadie entiende qué quiere esa cosa.",

	"movie.back_to_the_future.title": "De vuelta a ayer",
	"movie.back_to_the_future.syn": "Un chaval prueba un coche imposible que rompe el tiempo.\nUn fallo lo lanza a otra época… y altera su propia historia.\nPara volver, tendrá que arreglar lo que ha cambiado.\nY hacerlo antes de borrarse a sí mismo.",

	"movie.blade_runner.title": "Cazador de replicantes",
	"movie.blade_runner.syn": "En una ciudad de neón y lluvia, un ex-detective vuelve al trabajo.\nDebe “retirar” a unos seres artificiales que quieren respuestas.\nCada pista cuestiona qué significa ser humano.\nY el tiempo corre para todos.",

	"movie.dark_knight.title": "El caballero oscuro",
	"movie.dark_knight.syn": "La ciudad cree que por fin puede respirar, pero aparece un criminal sin reglas.\nNo busca dinero: busca demostrar que todo puede arder.\nEl héroe deberá elegir entre ganar… o corromperse.\nY cada decisión deja cicatriz.",

	"movie.die_hard.title": "Jungla de cristal",
	"movie.die_hard.syn": "Un policía llega a una fiesta… y el edificio queda tomado por asaltantes.\nSin apoyo, tendrá que improvisar piso a piso.\nLos rehenes son la moneda y el tiempo el enemigo.\nY cada paso hace ruido.",

	"movie.exorcist.title": "El exorcista",
	"movie.exorcist.syn": "Una niña empieza a comportarse de forma imposible y la razón se agota.\nSu madre busca ayuda mientras la situación empeora.\nLa Iglesia acepta intervenir con un ritual extremo.\nY la fe se vuelve un campo de batalla.",

	"movie.gladiator.title": "Gladiador",
	"movie.gladiator.syn": "Un general cae en desgracia tras una traición en la cima del poder.\nLe arrebatan su vida y lo obligan a sobrevivir como esclavo.\nEn la arena, cada combate es un mensaje.\nY la venganza se convierte en leyenda.",

	"movie.godfather.title": "El padrino",
	"movie.godfather.syn": "Una familia poderosa mantiene el control mientras el mundo cambia.\nLos pactos se rompen, la lealtad se compra y las deudas se cobran.\nEl heredero que no quería el trono aprende el precio.\nY el negocio se confunde con la familia.",

	"movie.jaws.title": "Tiburón",
	"movie.jaws.syn": "Un pueblo vive del verano… hasta que el mar deja de ser seguro.\nLa presión por mantener la calma choca con una amenaza invisible.\nTres hombres salen a buscar lo innombrable.\nY el agua se vuelve territorio hostil.",

	"movie.jurassic_park.title": "Parque jurásico",
	"movie.jurassic_park.syn": "Un parque imposible abre sus puertas con criaturas del pasado.\nUn grupo llega a validarlo… y todo falla.\nCuando el control se pierde, la isla cambia de reglas.\nY sobrevivir es la única visita guiada.",

	"movie.matrix.title": "La matriz",
	"movie.matrix.syn": "Un hacker sospecha que la realidad no encaja… y encuentra a quien puede responder.\nDescubre una guerra oculta y un mundo que no es lo que parece.\nAprenderá a romper límites que creía físicos.\nPero la verdad tiene un precio.",

	"movie.monty_python_and_the_holy_grail.title": "Los caballeros de la mesa cuadrada",
	"movie.monty_python_and_the_holy_grail.syn": "Un rey reúne a sus caballeros para una misión sagrada… con recursos ridículos.\nEl camino se llena de pruebas absurdas y enemigos aún más absurdos.\nLa lógica se rinde ante el caos.\nY la épica se convierte en una broma gigante.",

	"movie.pulp_fiction.title": "Tiempos pulp",
	"movie.pulp_fiction.syn": "Historias criminales se cruzan donde todo puede torcerse en segundos.\nDos sicarios filosofan mientras trabajan.\nUn boxeador rompe un trato peligroso.\nY una noche normal se vuelve una cadena de decisiones fatales.",

	"movie.raiders_of_the_lost_ark.title": "En busca del arca perdida",
	"movie.raiders_of_the_lost_ark.syn": "Un arqueólogo persigue una reliquia mítica antes de que caiga en manos equivocadas.\nLa búsqueda lo arrastra por templos, trampas y ciudades hostiles.\nLa aventura es constante, pero la amenaza también.\nY lo que está en juego no es solo un tesoro.",

	"movie.seven.title": "Siete",
	"movie.seven.syn": "Dos detectives investigan un caso espantoso que parece un mensaje.\nCada escena sube el listón y estrecha el cerco.\nPronto entienden que alguien sigue un plan simbólico.\nY que el final ya estaba decidido.",

	"movie.shining.title": "El resplandor",
	"movie.shining.syn": "Un escritor cuida un hotel aislado en invierno con su familia.\nEl lugar es enorme, silencioso… y demasiado lleno de ecos.\nLa soledad empieza a deformar la mente.\nY el hogar se convierte en un laberinto.",

	"movie.silence_of_the_lambs.title": "El silencio de los corderos",
	"movie.silence_of_the_lambs.syn": "Una agente novata busca a un asesino con un patrón inquietante.\nPara atraparlo, necesita hablar con un preso brillante y manipulador.\nCada conversación es un duelo.\nY cada pista acerca… y pone en riesgo.",

	"movie.terminator_two.title": "Terminator 2",
	"movie.terminator_two.syn": "Un chico es clave para el futuro y alguien viene a por él.\nEsta vez también llega un protector: frío, eficaz… y extraño.\nLa persecución escala a una guerra personal.\nY el destino parece reescribirse a golpes.",

	"movie.thing.title": "La cosa",
	"movie.thing.syn": "En una base aislada, un hallazgo desencadena paranoia pura.\nAlgo puede imitar a cualquiera… y nadie sabe quién es quién.\nLa confianza se rompe y cada decisión puede ser la última.\nEl frío no es lo peor del lugar.",

	"movie.two_thousand_and_one_a_space_odyssey.title": "2001: Odisea en el espacio",
	"movie.two_thousand_and_one_a_space_odyssey.syn": "Un hallazgo misterioso impulsa una misión hacia lo desconocido.\nA bordo, una IA controla cada sistema… y algo no cuadra.\nLa exploración se vuelve confrontación.\nY el viaje cambia la escala de lo humano.",
}

var _EN: Dictionary = {
	"ui.counter_ready": "[E] serve customer",
}
